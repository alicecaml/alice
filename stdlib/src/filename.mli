include module type of Stdlib.Filename

type t = string

module Set : Set.S with type elt = t
module Map : Map.S with type key = t

val equal : t -> t -> bool
val compare : t -> t -> int
val has_extension : t -> ext:string -> bool
val replace_extension : t -> ext:string -> t
