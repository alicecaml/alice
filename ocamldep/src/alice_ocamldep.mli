open! Alice_stdlib
open Alice_hierarchy

module Deps : sig
  type 'a t =
    { output : 'a Path.t
    ; inputs : 'a Path.t list
    }

  val to_dyn : _ t -> Dyn.t
end

val native_deps : 'a Path.t -> 'a Deps.t
