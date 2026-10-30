open! Alice_stdlib
module Builtin_module = Alice_builtin_module

module Inputs = struct
  type t =
    { dependencies : Dependencies.t
    ; builtin_modules : Builtin_module.Set.t
    }

  let to_dyn { dependencies; builtin_modules } =
    Dyn.record
      [ "dependencies", Dependencies.to_dyn dependencies
      ; "builtin_modules", Builtin_module.Set.to_dyn builtin_modules
      ]
  ;;

  let equal t { dependencies; builtin_modules } =
    Dependencies.equal t.dependencies dependencies
    && Builtin_module.Set.equal t.builtin_modules builtin_modules
  ;;

  let empty =
    { dependencies = Dependencies.empty; builtin_modules = Builtin_module.Set.empty }
  ;;
end

module Config_script_meta = struct
  type t = { inputs : Inputs.t }

  let to_dyn { inputs } = Dyn.record [ "inputs", Inputs.to_dyn inputs ]
  let equal t { inputs } = Inputs.equal t.inputs inputs
  let default = { inputs = Inputs.empty }

  let create ~dependencies ~builtin_modules =
    { inputs = { Inputs.dependencies; builtin_modules } }
  ;;

  let dependencies t = t.inputs.dependencies
  let builtin_modules t = t.inputs.builtin_modules
end

type t =
  { id : Package_id.t
  ; inputs : Inputs.t
  ; config_script : Config_script_meta.t
  }

let to_dyn { id; inputs; config_script } =
  Dyn.record
    [ "id", Package_id.to_dyn id
    ; "inputs", Inputs.to_dyn inputs
    ; "config_script", Config_script_meta.to_dyn config_script
    ]
;;

let equal t { id; inputs; config_script } =
  Package_id.equal t.id id
  && Inputs.equal t.inputs inputs
  && Config_script_meta.equal t.config_script config_script
;;

let create ~id ~dependencies ~builtin_modules ~config_script =
  { id; inputs = { Inputs.dependencies; builtin_modules }; config_script }
;;

let id { id; _ } = id
let name t = (id t).name
let version t = (id t).version
let dependencies t = t.inputs.dependencies
let builtin_modules t = t.inputs.builtin_modules
let config_script t = t.config_script
