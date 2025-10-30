open! Alice_stdlib

(** The type arguments determine what type of package is at the root of the
    dependency graph. This is mostly for convenience, since then a dependency
    graph completely captures all the things that need to be built in order to
    build the root package. *)
type ('exe, 'lib) t

val to_dyn : (_, _) t -> Dyn.t
val compute : ('exe, 'lib) Package.Typed.t -> ('exe, 'lib) t
val dot : (_, _) t -> string
val root : ('exe, 'lib) t -> ('exe, 'lib) Package.Typed.t

module Traverse_dependencies : sig
  (** The dependencies of a package are statically known to be libraries, but
      the root package may be an executable. Thus the dependencies must be
      traversed separately from the root package. This is a helper for
      traversing the transitive dependency closure of a package, excluding the
      package itself. *)
  type t

  val package_typed : t -> Package.Typed.lib_only_t
  val deps : t -> t list
end

val traverse_dependencies : (_, _) t -> Traverse_dependencies.t list
