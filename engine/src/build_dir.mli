open! Alice_stdlib
open Alice_hierarchy
open Alice_package

type t

val of_path : Path.Absolute.t -> t
val path : t -> Path.Absolute.t
val package_ocamldeps_cache_file : t -> Package_id.t -> Path.Absolute.t
val package_base_dir : t -> Package_id.t -> Profile.t -> Path.Absolute.t
val package_internal_dir : t -> Package_id.t -> Profile.t -> Path.Absolute.t
val package_lib_dir : t -> Package_id.t -> Profile.t -> Path.Absolute.t
val package_exe_dir : t -> Package_id.t -> Profile.t -> Path.Absolute.t
val package_dirs : t -> Package_id.t -> Profile.t -> Path.Absolute.t list

val package_role_dir
  :  t
  -> Package_id.t
  -> Profile.t
  -> Typed_op.Role.t
  -> Path.Absolute.t

val package_generated_file
  :  t
  -> Package_id.t
  -> Profile.t
  -> Typed_op.Generated_file.t
  -> Path.Absolute.t
