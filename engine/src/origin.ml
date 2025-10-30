open! Alice_stdlib
open Alice_hierarchy

module Build = struct
  type t =
    { inputs : Path.Absolute.Set.t
    ; outputs : Path.Absolute.Set.t
    ; commands : Command.t list
    }

  let to_dyn { inputs; outputs; commands } =
    Dyn.record
      [ "inputs", Path.Absolute.Set.to_dyn inputs
      ; "outputs", Path.Absolute.Set.to_dyn outputs
      ; "commands", Dyn.list Command.to_dyn commands
      ]
  ;;

  let equal t { inputs; outputs; commands } =
    Path.Absolute.Set.equal t.inputs inputs
    && Path.Absolute.Set.equal t.outputs outputs
    && List.equal ~eq:Command.equal t.commands commands
  ;;
end

type t =
  | Source of Path.Absolute.t
  | Build of Build.t

let to_dyn = function
  | Source path -> Dyn.variant "Source" [ Path.Absolute.to_dyn path ]
  | Build build -> Dyn.variant "Build" [ Build.to_dyn build ]
;;

let equal a b =
  match a, b with
  | Source a, Source b -> Path.Absolute.equal a b
  | Build a, Build b -> Build.equal a b
  | _, _ -> false
;;

let inputs = function
  | Source _ -> Path.Absolute.Set.empty
  | Build build -> build.inputs
;;

let outputs = function
  | Source path -> Path.Absolute.Set.singleton path
  | Build build -> build.outputs
;;
