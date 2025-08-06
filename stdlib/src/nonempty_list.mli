type 'a t = ( :: ) of ('a * 'a list)

val singleton : 'a -> 'a t
val of_list_opt : 'a list -> 'a t option
val to_list : 'a t -> 'a list
val to_dyn : 'a Dyn.builder -> 'a t Dyn.builder
val cons : 'a -> 'a t -> 'a t
val rev : 'a t -> 'a t
val map : 'a t -> f:('a -> 'b) -> 'b t
