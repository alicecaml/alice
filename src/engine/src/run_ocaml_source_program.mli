open! Alice_stdlib
open Alice_hierarchy
open Alice_error

val run_ocaml_source_program
  :  Build_config.t
  -> Alice_builtin_module.t list
  -> source_path:Absolute_path.non_root_t
  -> keep_artifacts:bool
  -> extra_compile_args:string list
  -> extra_link_args:string list
  -> args:string list
  -> unit User_error.result

val run_ocaml_source_program_capturing_stdout_lines
  :  Build_config.t
  -> Alice_builtin_module.t list
  -> source_path:Absolute_path.non_root_t
  -> extra_compile_args:string list
  -> extra_link_args:string list
  -> args:string list
  -> string list User_error.result
