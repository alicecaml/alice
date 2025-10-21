open! Alice_stdlib

type t = Dependency.t Package_name.Map.t

val empty : t
val equal : t -> t -> bool
val to_dyn : t -> Dyn.t
val names : t -> Package_name.t list
