include module type of Stdlib.Option

val map : 'a t -> f:('a -> 'b) -> 'b t
val bind : 'a t -> f:('a -> 'b t) -> 'b t
val iter : 'a t -> f:('a -> unit) -> unit
val equal : 'a t -> 'a t -> eq:('a -> 'a -> bool) -> bool
