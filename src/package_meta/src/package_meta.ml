open! Alice_stdlib
module Builtin_module = Alice_builtin_module

type t =
  { id : Package_id.t
  ; dependencies : Dependencies.t
  ; builtin_modules : Builtin_module.Set.t
  }

let to_dyn { id; dependencies; builtin_modules } =
  Dyn.record
    [ "id", Package_id.to_dyn id
    ; "dependencies", Dependencies.to_dyn dependencies
    ; "builtin_modules", Builtin_module.Set.to_dyn builtin_modules
    ]
;;

let equal t { id; dependencies; builtin_modules } =
  Package_id.equal t.id id
  && Dependencies.equal t.dependencies dependencies
  && Builtin_module.Set.equal t.builtin_modules builtin_modules
;;

let create ~id ~dependencies ~builtin_modules = { id; dependencies; builtin_modules }
let id { id; _ } = id
let name t = (id t).name
let version t = (id t).version
let dependencies { dependencies; _ } = dependencies
let builtin_modules { builtin_modules; _ } = builtin_modules
