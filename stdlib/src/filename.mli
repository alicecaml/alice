include module type of Stdlib.Filename

type t = string

val to_dyn : t -> Dyn.t

module Set : Set.S with type elt = t
module Map : Map.S with type key = t

val equal : t -> t -> bool
val compare : t -> t -> int
val has_extension : t -> ext:string -> bool
val replace_extension : t -> ext:string -> t
val add_extension : t -> ext:string -> t

(** Split a path into the sequence of names that make it up. The sequence of
    components will never be empty, either begining with the filesystem root or
    the current directory. *)
val to_components : t -> t Nonempty_list.t

val chop_prefix_opt : prefix:t -> t -> t option
val chop_prefix : prefix:t -> t -> t
