open! Alice_stdlib
open Alice_hierarchy

module Build_node : sig
  (** For the sake of simplicity, each node in the build graph corresponds to a
      single file. Most build operations produce multiple files, so the same
      operation may be associated with multiple nodes in the graph. When
      evaluating the build graph, care should be taken to not run the same
      operation multiple times. *)
  type t =
    { artifact : Path.Relative.t
      (** A single file produced by the associated operation. *)
    ; op : Typed_op.t
      (** An operation which creates [artifact], but which may also create other files. *)
    }
end

module Traverse : sig
  (** Helper for traversing a DAG. Traversals begin at output nodes. A
      traversal is a node in the DAG (an [Origin]) which knows how to expand
      the dependencies (inputs) to the node. Doesn't attempt to prevent
      visiting nodes multiple times. *)
  type t

  val origin : t -> Origin.t
  val outputs : t -> Path.Absolute.Set.t

  (** The list of nodes whose outputs are the inputs to the current node. *)
  val deps : t -> t list
end

(** A DAG that knows how to build a collection of interdependent files and the
    dependencies between each file. *)
type t

val to_dyn : t -> Dyn.t

(** [traverse t ~output] returns a traversal of [t] that produces the file
    [output] if the DAG [t] knows how to produce such a file, otherwise [None]. *)
val traverse : t -> output:Path.Absolute.t -> Traverse.t option

(** Returns the graphviz source code for rendering the build graph *)
val dot : t -> string

val create : Origin.Build.t list -> outputs:Path.Absolute.t list -> t
