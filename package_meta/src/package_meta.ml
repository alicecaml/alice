open! Alice_stdlib

type t =
  { id : Package_id.t
  ; dependencies : Dependencies.t option
    (** This is an [_ option] so that a manifest with an empty dependencies
        list and a manifest with no dependencies list can both round trip via
        this type. *)
  ; unix : bool option
    (** Whether the package needs access to the [Unix] module. This is a [bool
        option] so that a manifest
        with no [unix] field can be distinguished from a package that
        explicitly sets it to false when round-tripping a manifest. *)
  }

let to_dyn { id; dependencies; unix } =
  Dyn.record
    [ "id", Package_id.to_dyn id
    ; "dependencies", Dyn.option Dependencies.to_dyn dependencies
    ; "unix", Dyn.option Dyn.bool unix
    ]
;;

let equal t { id; dependencies; unix } =
  Package_id.equal t.id id
  && Option.equal t.dependencies dependencies ~eq:Dependencies.equal
  && Option.equal t.unix unix ~eq:Bool.equal
;;

let create ~id ~dependencies ~unix = { id; dependencies; unix }
let id { id; _ } = id
let name t = (id t).name
let version t = (id t).version

let dependencies { dependencies; _ } =
  Option.value dependencies ~default:Dependencies.empty
;;

let dependencies_ { dependencies; _ } = dependencies
let unix { unix; _ } = Option.value unix ~default:false
let unix_ { unix; _ } = unix
