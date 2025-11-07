include module type of Stdlib.ListLabels

val filter_opt : 'a option t -> 'a t
val last : 'a t -> 'a option
val split_last : 'a t -> ('a t * 'a) option
val all : bool t -> bool
val any : bool t -> bool
