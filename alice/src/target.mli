open! Alice_stdlib

module Os : sig
  type t =
    | Macos
    | Linux

  val to_dyn : t -> Dyn.t
end

module Arch : sig
  type t =
    | Aarch64
    | X86_64

  val to_dyn : t -> Dyn.t
end

module Linked : sig
  type t =
    | Dynamic
    | Static

  val to_dyn : t -> Dyn.t
end

type t

val to_dyn : t -> Dyn.t
val create : os:Os.t -> arch:Arch.t -> linked:Linked.t -> t
val to_string : t -> string

module Set : Set.S with type elt = t
module Map : Map.S with type key = t

val poll : unit -> t
