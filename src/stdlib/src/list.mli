include module type of Stdlib.ListLabels

val filter_opt : 'a option t -> 'a t
val last : 'a t -> 'a option
val split_last : 'a t -> ('a t * 'a) option
val all : bool t -> bool
val any : bool t -> bool
val zip : 'a t -> 'b t -> ('a * 'b) t

(** Return a duplicate item from the list if the list contains duplicates. The
    duplicate will be the lowest value according to the provided comparison
    function. *)
val any_duplicate : 'a t -> cmp:('a -> 'a -> int) -> 'a option
