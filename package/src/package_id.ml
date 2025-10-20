open! Alice_stdlib
open Alice_error
open Alice_hierarchy

type t =
  { name : Package_name.t
  ; version : Semantic_version.t
  }

let to_dyn { name; version } =
  Dyn.record
    [ "name", Package_name.to_dyn name; "version", Semantic_version.to_dyn version ]
;;

let name_dash_version_string { name; version } =
  String.concat
    ~sep:"-"
    [ Package_name.to_string name; Semantic_version.to_string version ]
;;

let name_v_version_string { name; version } =
  sprintf "%s v%s" (Package_name.to_string name) (Semantic_version.to_string version)
;;
