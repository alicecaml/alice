open! Alice_stdlib
open Alice_package

type t

val to_dyn : t -> Dyn.t

module Traverse : sig
  type t

  val package : t -> Package.t
  val deps : t -> t list
end

val traverse : t -> package_name:Package_name.t -> Traverse.t option
val dot : t -> string

module Staging : sig
  type dependency_graph := t
  type t

  val to_dyn : t -> Dyn.t
  val add_package : t -> Package.t -> t
  val finalize : t -> dependency_graph
end
