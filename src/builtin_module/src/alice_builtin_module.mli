open! Alice_stdlib
open Alice_error

type t =
  | Unix
  | Str

val to_dyn : t -> Dyn.t
val equal : t -> t -> bool
val compare : t -> t -> int

module Set : Set.S with type elt = t
module Map : Map.S with type key = t

val all : t list
val to_string : t -> string
val of_string_opt : string -> t option
val of_string_res : string -> (t, User_error.t) result
val of_string_exn : string -> t
