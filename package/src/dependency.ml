open! Alice_stdlib

type t =
  { name : Package_name.t
  ; source : Dependency_source.t
  }

let equal t { name; source } =
  Package_name.equal t.name name && Dependency_source.equal t.source source
;;

let to_dyn { name; source } =
  Dyn.record
    [ "name", Package_name.to_dyn name; "source", Dependency_source.to_dyn source ]
;;
