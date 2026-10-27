open! Alice_stdlib

type t =
  | Native
  | Bytecode

val equal : t -> t -> bool
val name : t -> string
val ocaml_object_file_ext : t -> string
