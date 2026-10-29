open! Alice_stdlib
open Alice_ocaml_toolchain
open Alice_hierarchy
module Builtin_module = Alice_builtin_module

let run_ocaml_source_program ocaml_toolchain builtin_modules ~source =
  let builtin_module_plus_args =
    List.concat_map builtin_modules ~f:(fun builtin_module ->
      [ "-I"; sprintf "+%s" (Builtin_module.to_string builtin_module) ])
  in
  let builtin_module_cma_args =
    List.map builtin_modules ~f:(fun builtin_module ->
      Ocaml_toolchain.builtin_module_ocaml_archive ocaml_toolchain Bytecode builtin_module
      |> Absolute_path.to_filename)
  in
  let command =
    Ocaml_toolchain.ocaml_command
      ocaml_toolchain
      ~args:
        (builtin_module_plus_args
         @ builtin_module_cma_args
         @ [ Absolute_path.to_filename source ])
  in
  match Alice_io.Process.Blocking.run_command command with
  | Ok report -> Alice_io.Process.Report.exn_unless_exit_0 report
  | Error error -> Alice_io.Process.Error.user_exn error
;;
