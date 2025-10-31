open! Alice_stdlib

type t =
  { name : Package_name.t
  ; version : Semantic_version.t
  }

val to_dyn : t -> Dyn.t
val equal : t -> t -> bool
val name : t -> Package_name.t
val version : t -> Semantic_version.t
val name_dash_version_string : t -> string
val name_v_version_string : t -> string
