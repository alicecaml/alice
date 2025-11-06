open! Alice_stdlib
open Alice_error

type t

module Set : Set.S with type elt = t
module Map : Map.S with type key = t

val to_dyn : t -> Dyn.t
val equal : t -> t -> bool
val compare : t -> t -> int
val of_string_res : string -> t user_result

(** Raises a user error *)
val of_string_exn : string -> t

val to_string : t -> string
