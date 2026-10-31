open! Alice_stdlib

type t =
  | Built
  | Reused

val is_built : t -> bool
val either_built : t -> t -> t
val any_built : t list -> t
