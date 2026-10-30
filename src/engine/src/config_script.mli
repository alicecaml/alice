open! Alice_stdlib
open Alice_package
open Alice_hierarchy

val run
  :  Build_dir.t
  -> Build_config.t
  -> Package_meta.t
  -> config_script_dependency_graph:Dependency_graph.t
  -> config_script_source_path:Absolute_path.non_root_t
  -> any_dep_rebuilt:bool
  -> unit
