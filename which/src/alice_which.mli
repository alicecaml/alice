open! Alice_stdlib

module Ocaml_compiler : sig
  type t

  val filename : t -> Filename.t
  val env : t -> Env.t
  val command : t -> args:string list -> Command.t
end

val ocamlopt : Alice_env.Os_type.t -> Env.t -> Ocaml_compiler.t
