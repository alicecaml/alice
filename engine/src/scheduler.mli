open! Alice_stdlib
open Alice_package
open Alice_ocaml_compiler

module Package_built : sig
  type t

  val any_rebuilt : t list -> bool
end

val run
  :  ('exe, 'lib) Build_graph.t
  -> ('exe, 'lib) Dependency_graph.Package_with_deps.t
  -> Profile.t
  -> Build_dir.t
  -> Ocaml_compiler.t
  -> any_dep_rebuilt:bool
  -> Package_built.t
