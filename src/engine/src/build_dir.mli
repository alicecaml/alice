open! Alice_stdlib
open Alice_hierarchy
open Alice_package
open Alice_ocaml_toolchain

(** The build directory for a project *)
type t

val basename : Basename.t
val of_project_root_path : Absolute_path.Root_or_non_root.t -> t
val path : t -> Absolute_path.non_root_t

val package_ocamldeps_cache_file
  :  t
  -> Package_id.t
  -> Compiler_backend.t
  -> Absolute_path.non_root_t

module Package_base_dir : sig
  type build_dir := t

  (** The directory which contains build artifacts for a particular package.
      Contains directories such as "public", "private", and "executable" *)
  type t

  val build_dir : t -> build_dir
  val generated_src_dir : t -> Absolute_path.non_root_t
  val private_dir : t -> Absolute_path.non_root_t
  val public_dir : t -> Absolute_path.non_root_t

  (** Directory for files generated for consumption by LSP. If package internals
    were made visible to LSP then it would suggest completions that aren't
    valid due to package hygiene. Instead, just the public interface to a
    library is made visible to LSP by way of this directory. The regular public
    directory can't be used for this purpose because of the generated public
    interface. *)
  val public_for_lsp_dir : t -> Absolute_path.non_root_t

  val executable_dir : t -> Absolute_path.non_root_t
  val dirs : t -> Absolute_path.non_root_t list
  val gen_file : t -> Op.Gen_file.t -> Absolute_path.non_root_t
end

val package_base_dir
  :  t
  -> Package_id.t
  -> Compiler_backend.t
  -> Profile.t
  -> Package_base_dir.t

val package_base_dir_of_build_config
  :  t
  -> Package_id.t
  -> Build_config.t
  -> Package_base_dir.t
