open! Alice_stdlib
open Alice_hierarchy
open Alice_package

type t

val of_path : Absolute_path.non_root_t -> t
val path : t -> Absolute_path.non_root_t
val package_ocamldeps_cache_file : t -> Package_id.t -> Absolute_path.non_root_t
val package_base_dir : t -> Package_id.t -> Profile.t -> Absolute_path.non_root_t
val package_private_dir : t -> Package_id.t -> Profile.t -> Absolute_path.non_root_t
val package_public_dir : t -> Package_id.t -> Profile.t -> Absolute_path.non_root_t
val package_executable_dir : t -> Package_id.t -> Profile.t -> Absolute_path.non_root_t
val package_dirs : t -> Package_id.t -> Profile.t -> Absolute_path.non_root_t list

val package_generated_file
  :  t
  -> Package_id.t
  -> Profile.t
  -> Typed_op.Generated_file.t
  -> Absolute_path.non_root_t
