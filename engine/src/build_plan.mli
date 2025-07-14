open! Alice_stdlib
module Path = Alice_hierarchy.Path.Relative

module Build : sig
  (** How to create a file by running a list of commands on a set of input
      files. *)
  type t =
    { inputs : Path.Set.t
    ; commands : Command.t list
    }
end

module Origin : sig
  (** The origin of a file, which can be either generated dynamically or
      already present in the project's source code. *)
  type t =
    | Source
    | Build of Build.t

  val inputs : t -> Path.Set.t
  val to_dyn : t -> Dyn.t
end

module Traverse : sig
  (** Helper for traversing a DAG *)
  type t

  val output : t -> Path.t
  val origin : t -> Origin.t
  val deps : t -> t list
end

(** A DAG that knows how to build a collection of interdependent files and the
    dependencies between each file. *)
type t

val to_dyn : t -> Dyn.t

(** [traverse t ~output] returns a traversal of [t] that produces the file
    [output] if the DAG [t] knows how to produce such a file, otherwise [None]. *)
val traverse : t -> output:Path.t -> Traverse.t option

module Staging : sig
  type build_plan := t
  type t

  val to_dyn : t -> Dyn.t
  val add_origin : t -> output:Path.t -> origin:Origin.t -> t
  val empty : t

  (** [finalize t] ensures that [t] contains no cycles and all input files have
      a corresponding node in the build graph, returning the validated build
      plan. *)
  val finalize : t -> build_plan
end
