include module type of MoreLabels.Map

module type S = sig
  include S

  val to_dyn : 'a Dyn.builder -> 'a t -> Dyn.t
  val of_list : (key * 'a) list -> ('a t, key * 'a * 'a) Result.t

  (** Raises [Invalid_argument] if the list contains duplicate keys *)
  val of_list_exn : (key * 'a) list -> 'a t

  val keys : 'a t -> key list
  val values : 'a t -> 'a list
end

module type Key = sig
  include OrderedType

  val to_dyn : t -> Dyn.t
end

module Make (Key : Key) : S with type key = Key.t
