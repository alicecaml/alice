open! Alice_stdlib

module Ocamlopt : sig
  type t

  val to_filename : t -> Filename.t
end

val ocamlopt : Alice_env.Env.t -> Ocamlopt.t
