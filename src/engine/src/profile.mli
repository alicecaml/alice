open! Alice_stdlib

type t

val ocaml_compiler_args : t -> string list
val debug : t
val release : t
val name : t -> string
