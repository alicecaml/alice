open! Alice_stdlib
open Alice_hierarchy
open Alice_package.Dependency_graph

val basename : Basename.t
val dot_merlin_text : (_, _) Package_with_deps.t -> Build_dir.t -> Profile.t -> string
