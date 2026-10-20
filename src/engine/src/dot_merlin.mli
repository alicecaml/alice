open! Alice_stdlib
open Alice_hierarchy
open Alice_ocaml_toolchain
open Alice_package.Dependency_graph

val basename : Basename.t
val dot_merlin_text_initial : unit -> string

val dot_merlin_text
  :  (_, _) Package_with_deps.t
  -> Build_dir.t
  -> Profile.t
  -> Ocaml_toolchain.t
  -> string
