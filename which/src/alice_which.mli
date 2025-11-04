open! Alice_stdlib

module Ocaml_compiler : sig
  type t

  val to_filename : t -> Filename.t
end

val ocamlopt : Alice_env.Os_type.t -> Alice_env.Env.t -> Ocaml_compiler.t
