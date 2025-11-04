open! Alice_stdlib

type t

val ocaml_compiler_command
  :  t
  -> Alice_which.Ocaml_compiler.t
  -> args:string list
  -> Command.t

val debug : t
val release : t
val name : t -> string
