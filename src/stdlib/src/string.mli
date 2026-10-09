include module type of StdLabels.String
module Set : Set.S with type elt = string
module Map : Map.S with type key = string

val is_empty : t -> bool
val lsplit2 : t -> on:char -> (t * t) option
val split_on_char_nonempty : t -> sep:char -> t Nonempty_list.t
