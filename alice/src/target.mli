open! Alice_stdlib
open Climate

module Os : sig
  type t =
    | Macos
    | Linux
    | Windows

  val to_dyn : t -> Dyn.t
  val to_string : t -> string
end

module Arch : sig
  type t =
    | Aarch64
    | X86_64

  val to_dyn : t -> Dyn.t
  val to_string : t -> string
end

module Linked : sig
  type t =
    | Dynamic
    | Static

  val to_dyn : t -> Dyn.t
  val to_string : t -> string
end

type t =
  { os : Os.t
  ; arch : Arch.t
  ; linked : Linked.t
  }

val to_dyn : t -> Dyn.t
val create : os:Os.t -> arch:Arch.t -> linked:Linked.t -> t
val to_string : t -> string

module Set : Set.S with type elt = t
module Map : Map.S with type key = t

val poll : Alice_env.Os_type.t -> Env.t -> t
val arg_parser : t Arg_parser.t
