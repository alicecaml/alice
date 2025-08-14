open! Alice_stdlib

type t

val to_dyn : t -> Dyn.t
val matches : version:Semantic_version.t -> t -> bool
val to_string : t -> string
val of_string_res : string -> (t, Ansi_style.t Pp.t list) result
val of_string : string -> t
