open! Alice_stdlib

type t

val to_dyn : t -> Dyn.t
val dot : t -> string
val compute : Package.t -> t
