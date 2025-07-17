open! Alice_stdlib

module Deps : sig
  type t =
    { output : Filename.t
    ; inputs : Filename.t list
    }

  val to_dyn : t -> Dyn.t
end

val native_deps : Filename.t -> Deps.t
