open! Alice_stdlib

type t =
  { name : Package_name.t
  ; source : Dependency_source.t
  }

val equal : t -> t -> bool
val to_dyn : t -> Dyn.t
