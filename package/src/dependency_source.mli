open! Alice_stdlib
open Alice_hierarchy

type t =
  | Local_directory of Path.Either.t (** The dependency is in a directory at this path *)

val to_dyn : t -> Dyn.t
