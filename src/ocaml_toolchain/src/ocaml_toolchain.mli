open! Alice_stdlib
open Alice_hierarchy
module Builtin_module = Alice_builtin_module

type t

(** [create ~ocamlopt ~ocaml env] creates a [t] representing an OCaml
    toolchain with tools at their respective paths with a given environment. *)
val create : ocamlopt:Filename.t -> ocaml:Filename.t -> Env.t -> t

val ocamlopt : t -> Filename.t
val ocaml : t -> Filename.t
val env : t -> Env.t
val ocamlopt_command : t -> args:string list -> Command.t
val ocaml_command : t -> args:string list -> Command.t

module Deps : sig
  type t =
    { output : Basename.t (** The path to the compiled output of a file. *)
    ; inputs : Basename.t list
      (** The files which must be generated before compiling a file. *)
    }

  val to_dyn : t -> Dyn.t
end

(** [depends_native_batch num_jobs files ~local_src_dir_path] takes a batch of
    source or interface files which exist in the directory at [local_src_dir_path]
    and returns the corresponding paths to files which will contain their
    compiled output ([Deps.output]), as well as the files which must be generated
    before compiling the given file ([Deps.inputs]). Returned paths are relative
    to the directory containing source files. *)
val depends_native_batch
  :  t
  -> Alice_io.Num_jobs.t
  -> local_src_dir_path:Absolute_path.non_root_t
  -> src_file_names:Basename.t list
  -> Deps.t list

(** Returns the "standard_library" path from the output of running the compiler
    with "-config". *)
val standard_library : t -> Absolute_path.non_root_t

(** The directory containing a builtin module within the compiler's standard
    library *)
val builtin_module_dir : t -> Builtin_module.t -> Absolute_path.non_root_t

(** The cmxa file for a builtin module within the compiler's standard
    library *)
val builtin_module_cmxa : t -> Builtin_module.t -> Absolute_path.non_root_t
