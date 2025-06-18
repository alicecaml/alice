include module type of Stdlib.Seq

val map : 'a t -> f:('a -> 'b) -> 'b t
val filter_map : 'a t -> f:('a -> 'b option) -> 'b t
val flat_map : 'a t -> f:('a -> 'b t) -> 'b t
val filter : 'a t -> f:('a -> bool) -> 'a t
val iter : 'a t -> f:('a -> unit) -> unit
