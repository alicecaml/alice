open! Alice_stdlib
open Alice_hierarchy

module Artifact_with_origin = struct
  module Name = Path.Relative

  (** A build artifact along with its origin. *)
  type t =
    { artifact : Path.Relative.t
    ; origin : Origin.t
    }

  let to_dyn { origin; artifact } =
    Dyn.record
      [ "artifact", Path.Relative.to_dyn artifact; "origin", Origin.to_dyn origin ]
  ;;

  let equal t { artifact; origin } =
    Path.Relative.equal t.artifact artifact && Origin.equal t.origin origin
  ;;

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
    Path.Relative.Set.fold (Origin.outputs origin) ~init:t ~f:(fun output t ->
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
