open! Alice_stdlib
open Alice_hierarchy

module Deps : sig
  type t =
    { output : Basename.t (** The path to the compiled output of a file. *)
    ; inputs : Basename.t list
      (** The files which must be generated before compiling a file. *)
    }

  val to_dyn : t -> Dyn.t
end

(** [native_deps file] takes the path to a source or interface file and returns
    the path to file which will contain its compiled output ([Deps.output]), as
    well as the files which must be generated before compiling the given file
    ([Deps.inputs]). Returned paths are relative to the directory containing
    [file]. *)
val native_deps : Absolute_path.non_root_t -> Deps.t
