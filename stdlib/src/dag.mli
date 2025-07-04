module type Name = sig
  type t

  val equal : t -> t -> bool
  val to_dyn : t -> Dyn.t

  module Set : Set.S with type elt = t
  module Map : Map.S with type key = t
end

module type S = sig
  type name
  type 'a node
  type 'a t

  val to_dyn : 'a Dyn.builder -> 'a t -> Dyn.t
  val empty : 'a t
  val add_node : 'a t -> name:name -> value:'a -> 'a t

  val add_edge
    :  'a t
    -> from:name
    -> to_:name
    -> ('a t, [ `Would_create_cycle_through of name list ]) result
end

module Make (Name : Name) : S with type name = Name.t
