open! Alice_stdlib

type t = private
  | Limited of int
  | Unlimited

val limited : int -> t
val unlimited : t

