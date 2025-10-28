open! Alice_stdlib
open Alice_package_meta

type t

val to_dyn : t -> Dyn.t

module Traverse : sig
  type t

  val package : t -> Package.t
  val deps : t -> t list
end

val traverse : t -> package_name:Package_name.t -> Traverse.t option
val dot : t -> string
val compute : Package.t -> t
