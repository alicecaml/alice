open! Alice_stdlib
open Alice_hierarchy

module Build = struct
  type t =
    { inputs : Path.Relative.Set.t
    ; outputs : Path.Relative.Set.t
    ; commands : Command.t list
    }

  let to_dyn { inputs; outputs; commands } =
    Dyn.record
      [ "inputs", Path.Relative.Set.to_dyn inputs
      ; "outputs", Path.Relative.Set.to_dyn outputs
      ; "commands", Dyn.list Command.to_dyn commands
      ]
  ;;

  let equal t { inputs; outputs; commands } =
    Path.Relative.Set.equal t.inputs inputs
    && Path.Relative.Set.equal t.outputs outputs
    && List.equal ~eq:Command.equal t.commands commands
  ;;
end

type t =
  | Source of Path.Relative.t
  | Build of Build.t

let to_dyn = function
  | Source path -> Dyn.variant "Source" [ Path.Relative.to_dyn path ]
  | Build build -> Dyn.variant "Build" [ Build.to_dyn build ]
;;

let equal a b =
  match a, b with
  | Source a, Source b -> Path.Relative.equal a b
  | Build a, Build b -> Build.equal a b
  | _, _ -> false
;;

let inputs = function
  | Source _ -> Path.Relative.Set.empty
  | Build build -> build.inputs
;;

let outputs = function
  | Source path -> Path.Relative.Set.singleton path
  | Build build -> build.outputs
;;
