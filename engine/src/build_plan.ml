open! Alice_stdlib
module Path = Alice_hierarchy.Path.Relative

module Build = struct
  type t =
    { inputs : Path.Set.t
    ; outputs : Path.Set.t
    ; commands : Command.t list
    }

  let to_dyn { inputs; outputs; commands } =
    Dyn.record
      [ "inputs", Path.Set.to_dyn inputs
      ; "outputs", Path.Set.to_dyn outputs
      ; "commands", Dyn.list Command.to_dyn commands
      ]
  ;;

  let equal t { inputs; outputs; commands } =
    Path.Set.equal t.inputs inputs
    && Path.Set.equal t.outputs outputs
    && List.equal ~eq:Command.equal t.commands commands
  ;;
end

module Origin = struct
  type t =
    | Source of Path.t
    | Build of Build.t

  let to_dyn = function
    | Source path -> Dyn.variant "Source" [ Path.to_dyn path ]
    | Build build -> Dyn.variant "Build" [ Build.to_dyn build ]
  ;;

  let equal a b =
    match a, b with
    | Source a, Source b -> Path.equal a b
    | Build a, Build b -> Build.equal a b
    | _, _ -> false
  ;;

  let inputs = function
    | Source _ -> Path.Set.empty
    | Build build -> build.inputs
  ;;

  let outputs = function
    | Source path -> Path.Set.singleton path
    | Build build -> build.outputs
  ;;
end

module Artifact_with_origin = struct
  module Name = Path

  (** A build artifact along with its origin. *)
  type t =
    { artifact : Path.t
    ; origin : Origin.t
    }

  let to_dyn { origin; artifact } =
    Dyn.record [ "artifact", Path.to_dyn artifact; "origin", Origin.to_dyn origin ]
  ;;

  let equal t { artifact; origin } =
    Path.equal t.artifact artifact && Origin.equal t.origin origin
  ;;

  let dep_names t = Origin.inputs t.origin
  let show t = Path.to_filename t.artifact
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
    Path.Set.fold (Origin.outputs origin) ~init:t ~f:(fun output t ->
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
