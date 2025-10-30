open! Alice_stdlib
open Alice_hierarchy
open Alice_package

type t

val of_path : Path.Absolute.t -> t
val package_ocamldeps_cache_file : t -> Package_id.t -> Path.Absolute.t
val package_artifacts_dir : t -> Package_id.t -> Profile.t -> Path.Absolute.t
