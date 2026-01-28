type 'a t = ( :: ) of 'a * 'a list

val singleton : 'a -> 'a t
val of_list_opt : 'a list -> 'a t option
val to_list : 'a t -> 'a list
val to_dyn : 'a Dyn.builder -> 'a t Dyn.builder
val cons : 'a -> 'a t -> 'a t
val rev : 'a t -> 'a t
val map : 'a t -> f:('a -> 'b) -> 'b t
val equal : eq:('a -> 'a -> bool) -> 'a t -> 'a t -> bool
val compare : cmp:('a -> 'a -> int) -> 'a t -> 'a t -> int
val last : 'a t -> 'a
val split_last : 'a t -> 'a list * 'a
