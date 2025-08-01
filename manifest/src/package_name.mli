open! Alice_stdlib

type t

val to_dyn : t -> Dyn.t
val of_string : string -> (t, Ansi_style.t Pp.t list) result
val of_string_exn : string -> t
val to_string : t -> string
