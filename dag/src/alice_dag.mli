open! Alice_stdlib

module type Node = sig
  module Name : sig
    type t

    module Set : Set.S with type elt = t
    module Map : Map.S with type key = t
  end

  (** A node in a DAG. Nodes have names which are used to link nodes to their
      dependencies in the graph. *)
  type t

  val to_dyn : t -> Dyn.t
  val equal : t -> t -> bool
  val dep_names : t -> Name.Set.t

  (** How to display this node when visualizing the graph with graphviz. *)
  val show : t -> string
end

module Make (Node : Node) : sig
  type t

  val empty : t
  val to_dyn : t -> Dyn.t

  (** Returns the graphviz source code for rendering the dag. *)
  val dot : t -> string

  module Traverse : sig
    (** Helper for traversing a DAG. Traversals begin at output nodes. A
        traversal is a node in the DAG which knows how to expand the
        dependencies of the node. Doesn't attempt to prevent visiting nodes
        multiple times. *)
    type t

    val node : t -> Node.t
    val deps : t -> t list
  end

  (** [traverse t ~name] returns a traversal of [t] starting at the node named
      [name] if such a node exists in [t], otherwise returns [None]. *)
  val traverse : t -> name:Node.Name.t -> Traverse.t option

  module Staging : sig
    type dag := t

    (** A graph which allows an incomplete representation. Use to construct
        DAGs one node at a time. An incomplete graph contains nodes with deps
        which are not present in the graph. *)
    type t

    val empty : t
    val to_dyn : t -> Dyn.t

    (** Add a node to the graph. The deps of the new node don't all need to be
        present in the graph. *)
    val add : t -> Node.Name.t -> Node.t -> (t, [ `Conflict of Node.t ]) result

    (** Returns a DAG provided that the staging graph is complete and free of
        cycles. *)
    val finalize
      :  t
      -> (dag, [ `Dangling of Node.Name.t | `Cycle of Node.Name.t list ]) result
  end
end
