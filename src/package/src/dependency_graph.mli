open! Alice_stdlib
open Alice_package_meta
module Builtin_module = Alice_builtin_module

type t

val to_dyn : t -> Dyn.t
val of_package_config_script_deps : Package.t -> t

module Package_with_deps : sig
  type dependency_graph := t
  type ('exe, 'lib) t
  type lib_only_t = (Type_bool.false_t, Type_bool.true_t) t

  val of_package_typed : ('exe, 'lib) Package.Typed.t -> ('exe, 'lib) t
  val dependency_graph : (_, _) t -> dependency_graph
  val package_typed : ('exe, 'lib) t -> ('exe, 'lib) Package.Typed.t
  val package : (_, _) t -> Package.t
  val package_id : (_, _) t -> Package_id.t
  val type_ : ('exe, 'lib) t -> ('exe, 'lib) Package.Typed.type_
  val name : (_, _) t -> Package_name.t
  val id : (_, _) t -> Package_id.t
  val builtin_modules : (_, _) t -> Builtin_module.Set.t
  val immediate_deps_in_dependency_order : (_, _) t -> lib_only_t list

  val transitive_dependency_closure_excluding_package
    :  (_, _) t
    -> Package.Typed.lib_only_t list

  val dot : (_, _) t -> string
end

val transitive_dependency_closure_in_dependency_order
  :  t
  -> Package_with_deps.lib_only_t list

val roots : t -> Package_with_deps.lib_only_t list
