open! Alice_stdlib
open Alice_hierarchy

val run_ocaml_source_program
  :  Build_config.t
  -> Alice_builtin_module.t list
  -> source_path:Absolute_path.non_root_t
  -> keep_artifacts:bool
  -> args:string list
  -> unit

val run_ocaml_source_program_capturing_stdout_lines
  :  Build_config.t
  -> Alice_builtin_module.t list
  -> source_path:Absolute_path.non_root_t
  -> args:string list
  -> (string list, Alice_io.Process.Status.t) result
