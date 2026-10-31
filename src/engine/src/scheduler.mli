open! Alice_stdlib
open Alice_package

val run
  :  ('exe, 'lib) Build_graph.t
  -> ('exe, 'lib) Dependency_graph.Package_with_deps.t
  -> Build_dir.Package_base_dir.t
  -> Build_config.t
  -> Config_script.Output.t
  -> any_dep_built:Built_status.t
  -> built_artifacts_from_deps:bool
  -> Built_status.t
