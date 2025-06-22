include module type of MoreLabels.Map

module type S = sig
  include S

  val find : 'a t -> key -> 'a option
  val set : 'a t -> key -> 'a -> 'a t
  val of_list : (key * 'a) list -> ('a t, key * 'a * 'a) Result.t
end

module Make (Key : OrderedType) : S with type key = Key.t
