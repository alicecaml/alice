include module type of Stdlib.Result

val map : ('a, 'e) t -> f:('a -> 'b) -> ('b, 'e) t
