open! Alice_stdlib
open Alice_hierarchy
open Alice_package_meta

val manifest_name : Basename.t
val read_package_dir : dir_path:_ Absolute_path.t -> Package_meta.t

val write_package_manifest
  :  manifest_path:Absolute_path.non_root_t
  -> Package_meta.t
  -> unit
