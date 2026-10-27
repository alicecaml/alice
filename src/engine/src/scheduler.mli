open! Alice_stdlib
open Alice_package
open Alice_ocaml_toolchain

module Package_built : sig
  type t

  val any_rebuilt : t list -> bool
end

val run
  :  ('exe, 'lib) Build_graph.t
  -> ('exe, 'lib) Dependency_graph.Package_with_deps.t
  -> Build_dir.t
  -> Build_config.t
  -> any_dep_rebuilt:bool
  -> built_artifacts_from_deps:bool
  -> Package_built.t
