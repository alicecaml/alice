open! Alice_stdlib

module type Node = sig
  module Name : sig
    type t

    val to_dyn : t -> Dyn.t

    module Set : Set.S with type elt = t
    module Map : Map.S with type key = t
  end

  (** A node in a DAG. Nodes have names which are used to link nodes to their
      dependencies in the graph. *)
  type t

  val to_dyn : t -> Dyn.t
  val equal : t -> t -> bool
  val name : t -> Name.t
  val dep_names : t -> Name.Set.t

  (** How to display this node when visualizing the graph with graphviz. *)
  val show : t -> string
end

module Make (Node : Node) : sig
  type t

  val empty : t
  val to_dyn : t -> Dyn.t
  val nodes : t -> Node.t list
  val roots : t -> Node.t list
  val to_string_graph : t -> String.Set.t String.Map.t

  (** Returns a list containing all nodes in the transitive dependency closure
      of the node [start] where each node appears a single time in the list,
      and a node will appear earlier than any dependant nodes in the list. If
      [include_start] is true then the final node will always be the one named
      in [start]. Otherwise [start] will not appear in the output. *)
  val transitive_closure_in_dependency_order
    :  t
    -> start:Node.Name.t
    -> include_start:bool
    -> Node.t list

  (** Returns a list where each node in [t] appears exactly once, in such an
      order than a node will appear earlier than any dependant nodes. *)
  val all_nodes_in_dependency_order : t -> Node.t list

  module Traverse : sig
    type dag := t

    (** Helper for traversing a DAG. Traversals begin at output nodes. A
        traversal is a node in the DAG which knows how to expand the
        dependencies of the node. Doesn't attempt to prevent visiting nodes
        multiple times. *)
    type t

    val node : t -> Node.t
    val name : t -> Node.Name.t
    val dag : t -> dag
    val deps : t -> t list
    val transitive_closure : t -> Node.t list
  end

  (** [traverse t ~name] returns a traversal of [t] starting at the node named
      [name], or panics if no such node exists. *)
  val traverse : t -> name:Node.Name.t -> Traverse.t

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

  val restage : t -> Staging.t
end
