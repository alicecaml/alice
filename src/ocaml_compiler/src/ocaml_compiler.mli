open! Alice_stdlib
open Alice_hierarchy

type t

(** [create filename env] creates a [t] representing a compiler whose
    executable is at [filename]. When the compiler is executed it will run in
    the specified environment [env]. This allows changes to the PATH variable
    to captured in [t]. *)
val create : Filename.t -> Env.t -> t

val filename : t -> Filename.t
val env : t -> Env.t
val command : t -> args:string list -> Command.t

module Deps : sig
  type t =
    { output : Basename.t (** The path to the compiled output of a file. *)
    ; inputs : Basename.t list
      (** The files which must be generated before compiling a file. *)
    }

  val to_dyn : t -> Dyn.t
end

(** [depends_native_batch file] takes a batch of paths to source or interface files
    and returns the corresponding paths to files which will contain their
    compiled output ([Deps.output]), as well as the files which must be
    generated before compiling the given file ([Deps.inputs]). Returned paths
    are relative to the directory containing source files. *)
val depends_native_batch
  :  t
  -> Alice_io.Num_jobs.t
  -> Absolute_path.non_root_t list
  -> Deps.t list

(** Returns the "standard_library" path from the output of running the compiler
    with "-config". *)
val standard_library : t -> Absolute_path.non_root_t
