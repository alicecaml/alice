open! Alice_stdlib

module type Node = sig
  (** A node in a DAG. Nodes have names which are used to link nodes to their
      dependencies in the graph. *)
  type t

  type name

  module Name_set : Set.S with type elt = name
  module Name_map : Map.S with type key = name

  val to_dyn : t -> Dyn.t
  val equal : t -> t -> bool
  val deps : t -> Name_set.t
end

module Make (Node : Node) : sig
  type t

  val empty : t
  val to_dyn : t -> Dyn.t
  val to_list : t -> (Node.name * Node.t) list

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
  val traverse : t -> name:Node.name -> Traverse.t option

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
    val add : t -> Node.name -> Node.t -> (t, [ `Conflict of Node.t ]) result

    (** Returns a DAG provided that the staging graph is complete and free of
        cycles. *)
    val finalize
      :  t
      -> (dag, [ `Dangling of Node.name | `Cycle of Node.name list ]) result
  end
end
