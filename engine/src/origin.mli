open! Alice_stdlib
open Alice_hierarchy

module Build : sig
  (** How to create a set of output files by running a list of commands on a
      set of input files. *)
  type t =
    { inputs : Path.Absolute.Set.t
    ; outputs : Path.Absolute.Set.t
    ; commands : Command.t list
    }

  val to_dyn : t -> Dyn.t
end

(** The origin of a file, which can be either generated dynamically or
    already present in the project's source code. *)
type t =
  | Source of Path.Absolute.t
  | Build of Build.t

val inputs : t -> Path.Absolute.Set.t
val outputs : t -> Path.Absolute.Set.t
val to_dyn : t -> Dyn.t
val equal : t -> t -> bool
