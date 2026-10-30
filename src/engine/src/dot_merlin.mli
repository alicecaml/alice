open! Alice_stdlib
open Alice_hierarchy
open Alice_package

val basename : Basename.t
val dot_merlin_text_initial : unit -> string

val dot_merlin_text
  :  (_, _) Dependency_graph.Package_with_deps.t
  -> Build_dir.t
  -> Build_config.t
  -> config_script_dependency_graph:Dependency_graph.t
  -> string
