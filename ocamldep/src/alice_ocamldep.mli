open! Alice_stdlib
open Alice_hierarchy

module Deps : sig
  type 'a t =
    { output : 'a Path.t (** The path to the compiled output of a file. *)
    ; inputs : 'a Path.t list
      (** The files which must be generated before compiling a file. *)
    }

  val to_dyn : _ t -> Dyn.t
end

(** Given the path to a source or interface file, return the path to file which
    will contain its compiled output ([Deps.output]), as well as the files which
    must be generated before compiling the given file ([Deps.inputs]). *)
val native_deps : 'a Path.t -> 'a Deps.t
