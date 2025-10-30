open! Alice_stdlib
open Alice_hierarchy

module Artifact_with_origin = struct
  module Name = Path.Absolute

  (** A build artifact along with its origin. *)
  type t =
    { artifact : Path.Absolute.t
    ; origin : Origin.t
    }

  let to_dyn { origin; artifact } =
    Dyn.record
      [ "artifact", Path.Absolute.to_dyn artifact; "origin", Origin.to_dyn origin ]
  ;;

  let equal t { artifact; origin } =
    Path.Absolute.equal t.artifact artifact && Origin.equal t.origin origin
  ;;

  let name t = t.artifact
  let dep_names t = Origin.inputs t.origin
  let show t = Alice_ui.path_to_string t.artifact
end

include Alice_dag.Make (Artifact_with_origin)

module Traverse = struct
  include Traverse

  let origin t = (node t).origin
  let outputs t = Origin.outputs (origin t)
end

let traverse t ~output = traverse t ~name:output

module Staging = struct
  include Staging

  let add_origin t origin =
    Path.Absolute.Set.fold (Origin.outputs origin) ~init:t ~f:(fun output t ->
      let artifact_with_origin = { Artifact_with_origin.artifact = output; origin } in
      match add t output artifact_with_origin with
      | Ok t -> t
      | Error (`Conflict _) ->
        Alice_error.panic
          [ Pp.textf "Conflicting origins for file: %s" (Alice_ui.path_to_string output) ])
  ;;

  let finalize t =
    match finalize t with
    | Ok t -> t
    | Error (`Dangling dangling) ->
      Alice_error.panic
        [ Pp.textf "No rule to build: %s" (Alice_ui.path_to_string dangling) ]
    | Error (`Cycle cycle) ->
      Alice_error.panic
        ([ Pp.text "Dependency cycle:"; Pp.newline ]
         @ List.concat_map cycle ~f:(fun file ->
           [ Pp.textf " - %s" (Alice_ui.path_to_string file); Pp.newline ]))
  ;;
end

let dot t = to_string_graph t |> Alice_graphviz.dot_src_of_string_graph

let create builds ~outputs =
  let find_for_output_file_opt ~output =
    List.find_opt builds ~f:(fun (build : Origin.Build.t) ->
      Path.Absolute.Set.mem output build.outputs)
  in
  let rec loop output acc =
    let origin =
      match find_for_output_file_opt ~output with
      | None -> Origin.Source output
      | Some build -> Origin.Build build
    in
    let acc = Staging.add_origin acc origin in
    Origin.inputs origin |> Path.Absolute.Set.fold ~init:acc ~f:loop
  in
  let staged =
    List.fold_left outputs ~init:Staging.empty ~f:(fun acc output -> loop output acc)
  in
  Staging.finalize staged
;;
