open! Alice_stdlib
open Alice_ocaml_compiler

type t

val ocaml_compiler_command : t -> Ocaml_compiler.t -> args:string list -> Command.t
val debug : t
val release : t
val name : t -> string
