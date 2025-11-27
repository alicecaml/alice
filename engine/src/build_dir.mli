open! Alice_stdlib
open Alice_hierarchy
open Alice_package

type t

val of_path : Absolute_path.non_root_t -> t
val path : t -> Absolute_path.non_root_t
val package_ocamldeps_cache_file : t -> Package_id.t -> Absolute_path.non_root_t
val package_base_dir : t -> Package_id.t -> Profile.t -> Absolute_path.non_root_t

val package_generated_source_dir
  :  t
  -> Package_id.t
  -> Profile.t
  -> Absolute_path.non_root_t

val package_private_dir : t -> Package_id.t -> Profile.t -> Absolute_path.non_root_t
val package_public_dir : t -> Package_id.t -> Profile.t -> Absolute_path.non_root_t

(** Directory for files generated for consumption by LSP. If package internals
    were made visible to LSP then it would suggest completions that aren't
    valid due to package hygiene. Instead, just the public interface to a
    library is made visible to LSP by way of this directory. The regular public
    directory can't be used for this purpose because of the generated public
    interface. *)
val package_public_for_lsp_dir
  :  t
  -> Package_id.t
  -> Profile.t
  -> Absolute_path.non_root_t

val package_executable_dir : t -> Package_id.t -> Profile.t -> Absolute_path.non_root_t
val package_dirs : t -> Package_id.t -> Profile.t -> Absolute_path.non_root_t list

val package_generated_file_compiled
  :  t
  -> Package_id.t
  -> Profile.t
  -> Typed_op.Generated_file.Compiled.t
  -> Absolute_path.non_root_t

val package_generated_file
  :  t
  -> Package_id.t
  -> Profile.t
  -> Typed_op.Generated_file.t
  -> Absolute_path.non_root_t
