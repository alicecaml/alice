open! Alice_stdlib

type t =
  { name : Package_name.t
  ; source : Dependency_source.t
  }

let create ~name ~source = { name; source }

let equal t { name; source } =
  Package_name.equal t.name name && Dependency_source.equal t.source source
;;

let to_dyn { name; source } =
  Dyn.record
    [ "name", Package_name.to_dyn name; "source", Dependency_source.to_dyn source ]
;;

let name { name; _ } = name
let source { source; _ } = source
