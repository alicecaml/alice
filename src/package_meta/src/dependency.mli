open! Alice_stdlib

type t

val create : name:Package_name.t -> source:Dependency_source.t -> t
val equal : t -> t -> bool
val to_dyn : t -> Dyn.t
val name : t -> Package_name.t
val source : t -> Dependency_source.t
