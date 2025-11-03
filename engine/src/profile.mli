open! Alice_stdlib

type t

val ocamlopt_command
  :  t
  -> args:string list
  -> ocamlopt:Alice_which.Ocamlopt.t
  -> Command.t

val debug : t
val release : t
val name : t -> string
