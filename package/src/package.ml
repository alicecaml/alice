open! Alice_stdlib

type t =
  { id : Package_id.t
  ; dependencies : Dependencies.t option
    (** This is an [_ option] so that a manifest with an empty dependencies
        list and a manifest with no dependencies list can both round trip via
        this type. *)
  }

let to_dyn { id; dependencies } =
  Dyn.record
    [ "id", Package_id.to_dyn id
    ; "dependencies", Dyn.option Dependencies.to_dyn dependencies
    ]
;;

let equal t { id; dependencies } =
  Package_id.equal t.id id
  && Option.equal t.dependencies dependencies ~eq:Dependencies.equal
;;

let create ~id ~dependencies = { id; dependencies }
let id { id; _ } = id
let name t = (id t).name
let version t = (id t).version

let dependencies { dependencies; _ } =
  Option.value dependencies ~default:Dependencies.empty
;;

let dependencies_ { dependencies; _ } = dependencies
