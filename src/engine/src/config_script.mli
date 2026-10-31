open! Alice_stdlib
open Alice_package
open Alice_hierarchy

module Output : sig
  type t =
    { lines_to_print : string list
    ; c_linker_args : string list
    }

  val default : t
end

val run
  :  Build_dir.t
  -> Package_meta.t
  -> package_build_config:Build_config.t
  -> config_script_build_config:Build_config.t
  -> config_script_dependency_graph:Dependency_graph.t
  -> config_script_source_path:Absolute_path.non_root_t
  -> any_dep_built:Built_status.t
  -> Output.t * Built_status.t
