open! Alice_stdlib

type t

val ocamlopt_command : t -> args:string list -> Command.t
val debug : t
val release : t
val name : t -> string
