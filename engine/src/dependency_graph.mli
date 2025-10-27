open! Alice_stdlib
open Alice_package_meta

type t

val to_dyn : t -> Dyn.t

module Traverse : sig
  type t

  val package : t -> Package_meta.t
  val deps : t -> t list
end

val traverse : t -> package_name:Package_name.t -> Traverse.t option
val dot : t -> string

module Staging : sig
  type dependency_graph := t
  type t

  val to_dyn : t -> Dyn.t
  val empty : t
  val add_package : t -> Package_meta.t -> t
  val finalize : t -> dependency_graph
end
