include module type of MoreLabels.Set

module type S = sig
  include S

  val to_dyn : t -> Dyn.t
end

module type Ord = sig
  include OrderedType

  val to_dyn : t -> Dyn.t
end

module Make (Ord : Ord) : S with type elt = Ord.t
