open! Alice_stdlib

module Os : sig
  type t =
    | Macos
    | Linux
end

module Arch : sig
  type t =
    | Aarch64
    | X86_64
end

module Linked : sig
  type t =
    | Dynamic
    | Static
end

type t

val create : os:Os.t -> arch:Arch.t -> linked:Linked.t -> t
val to_string : t -> string

module Set : Set.S with type elt = t
module Map : Map.S with type key = t

val poll : unit -> t
