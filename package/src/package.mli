open! Alice_stdlib
open Alice_hierarchy
open Alice_package_meta

type t

val to_dyn : t -> Dyn.t
val equal : t -> t -> bool
val create : root:Path.Absolute.t -> meta:Package_meta.t -> t
val read_root : Path.Absolute.t -> t
val root : t -> Path.Absolute.t
val meta : t -> Package_meta.t
val id : t -> Package_id.t
val name : t -> Package_name.t
val version : t -> Semantic_version.t
val dependencies : t -> Dependencies.t
