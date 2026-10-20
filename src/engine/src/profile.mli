open! Alice_stdlib
open Alice_ocaml_toolchain

type t

val ocamlopt_command : t -> Ocaml_toolchain.t -> args:string list -> Command.t
val debug : t
val release : t
val name : t -> string
