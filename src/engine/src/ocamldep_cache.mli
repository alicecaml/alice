open! Alice_stdlib
open Alice_hierarchy
open Alice_package
open Alice_ocaml_toolchain

type dep_table = Ocaml_toolchain.Deps.t Absolute_path.Non_root_map.t

(** Cache which is serialized in the build directory to avoid running ocamldep
    when it's output is guaranteed to be the same as the previous time it was
    run on some file. *)
type t

(** Load the cache for the given package from the build directory if it exists,
    otherwise return an empty cache. *)
val load : Build_dir.t -> Compiler_backend.t -> Package_id.t -> t

(** Overwrite the cache in the build directory with an updated dep table. *)
val store : t -> Compiler_backend.t -> dep_table -> unit

(** Look up the deps of a batch of source files, invoking ocamldep for files
    not present or up to date in the cache. *)
val get_deps_batch
  :  t
  -> Ocaml_toolchain.t
  -> Compiler_backend.t
  -> Alice_io.Num_jobs.t
  -> local_src_dir_path:Absolute_path.non_root_t
  -> src_file_names:Basename.t list
  -> (Absolute_path.non_root_t * Ocaml_toolchain.Deps.t) list
