open! Alice_stdlib

(** The type arguments determine what type of package is at the root of the
    dependency graph. This is mostly for convenience, since then a dependency
    graph completely captures all the things that need to be built in order to
    build the root package. *)
type ('exe, 'lib) t

val to_dyn : (_, _) t -> Dyn.t
val compute : ('exe, 'lib) Package.Typed.t -> ('exe, 'lib) t
val dot : (_, _) t -> string

module Package_with_deps : sig
  type ('exe, 'lib) t =
    { package : ('exe, 'lib) Package.Typed.t
    ; immediate_deps : Package.Typed.lib_only_t list
    }
end

(** Returns the transitive closure of dependencies excluding the package at the
    root of the dependency graph. This lets us statically know that each
    dependency is a library package, while the root package may not be. *)
val transitive_dependency_closure_in_dependency_order
  :  (_, _) t
  -> (Type_bool.false_t, Type_bool.true_t) Package_with_deps.t list

val root_package_with_deps : ('exe, 'lib) t -> ('exe, 'lib) Package_with_deps.t
