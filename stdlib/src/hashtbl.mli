module type S = sig
  include MoreLabels.Hashtbl.S

  val find_or_add : 'a t -> key -> f:(key -> 'a) -> 'a
end

module Make (Key : sig
    include MoreLabels.Hashtbl.HashedType
  end) : S with type key = Key.t
