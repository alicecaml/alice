include module type of StdLabels.String
module Set : Set.S with type elt = string
module Map : Map.S with type key = string

val is_empty : t -> bool
val lsplit2 : t -> on:char -> (t * t) option
