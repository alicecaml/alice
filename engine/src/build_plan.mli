open! Alice_stdlib
module Path = Alice_hierarchy.Path.Relative

module Build : sig
  (** How to create a set of output files by running a list of commands on a
      set of input files. *)
  type t =
    { inputs : Path.Set.t
    ; outputs : Path.Set.t
    ; commands : Command.t list
    }

  val to_dyn : t -> Dyn.t
end

module Origin : sig
  (** The origin of a file, which can be either generated dynamically or
      already present in the project's source code. *)
  type t =
    | Source of Path.t
    | Build of Build.t

  val inputs : t -> Path.Set.t
  val outputs : t -> Path.Set.t
  val to_dyn : t -> Dyn.t
end

module Traverse : sig
  (** Helper for traversing a DAG. Traversals begin at output nodes. A
      traversal is a node in the DAG (an [Origin]) which knows how to expand
      the dependencies (inputs) to the node. Doesn't attempt to prevent
      visiting nodes multiple times. *)
  type t

  val origin : t -> Origin.t
  val outputs : t -> Path.Set.t

  (** The list of nodes whose outputs are the inputs to the current node. *)
  val deps : t -> t list
end

(** A DAG that knows how to build a collection of interdependent files and the
    dependencies between each file. *)
type t

val to_dyn : t -> Dyn.t

(** [traverse t ~output] returns a traversal of [t] that produces the file
    [output] if the DAG [t] knows how to produce such a file, otherwise [None]. *)
val traverse : t -> output:Path.t -> Traverse.t option

(** Returns the graphviz source code for rendering the build graph *)
val dot : t -> string

module Staging : sig
  type build_plan := t
  type t

  val to_dyn : t -> Dyn.t
  val add_origin : t -> Origin.t -> t
  val empty : t

  (** [finalize t] ensures that [t] contains no cycles and all input files have
      a corresponding node in the build graph, returning the validated build
      plan. *)
  val finalize : t -> build_plan
end
