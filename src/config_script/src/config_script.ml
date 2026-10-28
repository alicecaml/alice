open! Alice_stdlib
open Alice_ocaml_toolchain
open Alice_hierarchy
module Builtin_module = Alice_builtin_module

let _run_ocaml_program ocaml_toolchain source_path builtin_modules =
  let builtin_module_plus_args =
    List.concat_map builtin_modules ~f:(fun builtin_module ->
      [ "-I"; sprintf "+%s" (Builtin_module.to_string builtin_module) ])
  in
  let builtin_module_cma_args =
    List.map builtin_modules ~f:(fun builtin_module ->
      Ocaml_toolchain.builtin_module_ocaml_archive ocaml_toolchain Bytecode builtin_module
      |> Absolute_path.to_filename)
  in
  let _command =
    Ocaml_toolchain.ocaml_command
      ocaml_toolchain
      ~args:
        (builtin_module_plus_args
         @ builtin_module_cma_args
         @ [ Absolute_path.to_filename source_path ])
  in
  ()
;;
