open! Alice_stdlib

type t =
  { id : Package_id.t
  ; dependencies : Dependencies.t
  ; unix : bool
  }

let to_dyn { id; dependencies; unix } =
  Dyn.record
    [ "id", Package_id.to_dyn id
    ; "dependencies", Dependencies.to_dyn dependencies
    ; "unix", Dyn.bool unix
    ]
;;

let equal t { id; dependencies; unix } =
  Package_id.equal t.id id
  && Dependencies.equal t.dependencies dependencies
  && Bool.equal t.unix unix
;;

let create ~id ~dependencies ~unix = { id; dependencies; unix }
let id { id; _ } = id
let name t = (id t).name
let version t = (id t).version
let dependencies { dependencies; _ } = dependencies
let unix { unix; _ } = unix
