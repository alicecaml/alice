include module type of MoreLabels.Map

module type S = sig
  include S

  val find_exn : 'a t -> key -> 'a
  val find : 'a t -> key -> 'a option
  val set : 'a t -> key -> 'a -> 'a t
  val of_list : (key * 'a) list -> ('a t, key * 'a * 'a) Result.t

  (** Raises [Invalid_argument] if the list contains duplicate keys *)
  val of_list_exn : (key * 'a) list -> 'a t
end

module Make (Key : OrderedType) : S with type key = Key.t
