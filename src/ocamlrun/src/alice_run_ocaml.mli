open! Alice_stdlib
open Alice_ocaml_toolchain
open Alice_hierarchy

val run_ocaml_source_program
  :  Ocaml_toolchain.t
  -> Alice_builtin_module.t list
  -> source:Absolute_path.non_root_t
  -> unit
