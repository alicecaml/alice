open! Alice_stdlib

type t = Dependency.t Package_name.Map.t

val empty : t
val to_dyn : t -> Dyn.t
