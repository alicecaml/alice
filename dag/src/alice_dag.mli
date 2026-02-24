open! Alice_stdlib

module type Name = sig
  type t

  val to_dyn : t -> Dyn.t
  val equal : t -> t -> bool

  module Set : Set.S with type elt = t
  module Map : Map.S with type key = t
end

module Make (Name : Name) : sig
  type 'a t

  val to_dyn : 'a Dyn.builder -> 'a t -> Dyn.t

  module Node : sig
    type 'a t

    val to_dyn : 'a Dyn.builder -> 'a t -> Dyn.t
    val name : _ t -> Name.t
    val value : 'a t -> 'a
    val children : 'a t -> 'a t list

    (** [transitive_closure_in_child_first_order t ~include_start] returns a
        list containing all nodes in the transitive closure of the node [t]
        where each node appears a single time in the list, and a node will
        appear earlier than any parent nodes in the list. If [include_start] is
        true then the final node will always be [t] in [t]. Otherwise [start]
        will not appear in the output. *)
    val transitive_closure_in_child_first_order : 'a t -> include_start:bool -> 'a t list
  end

  val roots : 'a t -> 'a Node.t list
  val get_node : 'a t -> name:Name.t -> 'a Node.t

  val to_string_graph
    :  'a t
    -> node_to_string:('a Node.t -> string)
    -> String.Set.t String.Map.t

  val all_nodes : 'a t -> 'a Node.t list
  val all_names : _ t -> Name.t list

  (** Returns a list where each node in [t] appears exactly once, in such an
      order than a node will appear earlier than any parent nodes. *)
  val all_nodes_in_child_first_order : 'a t -> 'a Node.t list

  module Staging : sig
    type 'a dag := 'a t

    (** A graph which allows an incomplete representation. Use to construct
        DAGs one node at a time. An incomplete graph contains nodes with deps
        which are not present in the graph. *)
    type 'a t

    val empty : _ t

    (** Add a node to the graph. The deps of the new node don't all need to be
        present in the graph. *)
    val add
      :  'a t
      -> Name.t
      -> 'a
      -> eq:('a -> 'a -> bool)
      -> child_names:Name.t list
      -> ('a t, [ `Conflict ]) result

    (** Like [add] but panics on error *)
    val add_or_panic
      :  'a t
      -> Name.t
      -> 'a
      -> eq:('a -> 'a -> bool)
      -> child_names:Name.t list
      -> 'a t

    (** Returns a DAG provided that the staging graph is complete and free of
        cycles. *)
    val finalize
      :  'a t
      -> ('a dag, [ `Dangling of Name.t | `Cycle of Name.t list ]) result

    (** Like [finalize] but panics on error *)
    val finalize_or_panic : 'a t -> 'a dag
  end

  val restage : 'a t -> 'a Staging.t
end
