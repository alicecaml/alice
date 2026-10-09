open! Alice_stdlib

type t

val empty : t
val equal : t -> t -> bool
val to_dyn : t -> Dyn.t
val names : t -> Package_name.t list
val to_list : t -> Dependency.t list
val of_list : Dependency.t list -> (t, [ `Duplicate_name of Package_name.t ]) result
