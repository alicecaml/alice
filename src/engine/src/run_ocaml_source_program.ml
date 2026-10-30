open! Alice_stdlib
open Alice_ocaml_toolchain
open Alice_hierarchy
open Alice_io
module Builtin_module = Alice_builtin_module

let with_built_ocaml_program_command
      (build_config : Build_config.t)
      builtin_modules
      ~source_path
      ~keep_artifacts
      ~extra_compile_args
      ~extra_link_args
      ~args
      ~f
  =
  if not (File_ops.exists source_path)
  then
    Alice_error.user_exn
      [ Pp.textf "File %S does not exist." (Absolute_path.to_filename source_path) ];
  let builtin_module_plus_args =
    List.concat_map builtin_modules ~f:(fun builtin_module ->
      [ "-I"; sprintf "+%s" (Builtin_module.to_string builtin_module) ])
  in
  let builtin_module_cma_args =
    List.map builtin_modules ~f:(fun builtin_module ->
      Ocaml_toolchain.builtin_module_ocaml_archive
        build_config.ocaml_toolchain
        build_config.compiler_backend
        builtin_module
      |> Absolute_path.to_filename)
  in
  Alice_io.Temp_dir.with_
    ~prefix:"alice-"
    ~suffix:""
    ~keep:keep_artifacts
    ~f:(fun dir_path ->
      let out_basename_without_ext = Basename.of_filename "program" in
      let out_basename_exe =
        Alice_env.Os_type.basename_add_exe_extension_on_windows
          build_config.os_type
          out_basename_without_ext
      in
      let out_basename_obj =
        Basename.add_extension
          out_basename_without_ext
          ~ext:(Compiler_backend.ocaml_object_file_ext build_config.compiler_backend)
      in
      let compile_command =
        Ocaml_toolchain.compiler_command
          build_config.compiler_backend
          build_config.ocaml_toolchain
          ~args:
            (builtin_module_plus_args
             @ builtin_module_cma_args
             @ Profile.ocaml_compiler_args build_config.profile
             @ extra_compile_args
             @ [ Absolute_path.to_filename source_path
               ; "-c"
               ; "-o"
               ; Absolute_path.to_filename (dir_path / out_basename_obj)
               ])
      in
      let link_command =
        Ocaml_toolchain.compiler_command
          build_config.compiler_backend
          build_config.ocaml_toolchain
          ~args:
            (builtin_module_plus_args
             @ builtin_module_cma_args
             @ Profile.ocaml_compiler_args build_config.profile
             @ extra_link_args
             @ [ Absolute_path.to_filename (dir_path / out_basename_obj)
               ; "-o"
               ; Absolute_path.to_filename (dir_path / out_basename_exe)
               ])
      in
      let open Result.O in
      let* () =
        Process.Blocking.run_command compile_command
        |> Process.Blocking.result_to_user_result
      in
      let* () =
        Process.Blocking.run_command link_command
        |> Process.Blocking.result_to_user_result
      in
      let run_command =
        Command.create
          (Absolute_path.to_filename (dir_path / out_basename_exe))
          ~args
          (Ocaml_toolchain.env build_config.ocaml_toolchain)
      in
      f run_command)
;;

let run_ocaml_source_program
      build_config
      builtin_modules
      ~source_path
      ~keep_artifacts
      ~extra_compile_args
      ~extra_link_args
      ~args
  =
  with_built_ocaml_program_command
    build_config
    builtin_modules
    ~source_path
    ~keep_artifacts
    ~extra_compile_args
    ~extra_link_args
    ~args
    ~f:(fun command ->
      let open Result.O in
      let+ () =
        Process.Blocking.run_command command |> Process.Blocking.result_to_user_result
      in
      if keep_artifacts
      then
        print_endline
          (sprintf "Build artifacts kept at: %s" (Filename.dirname command.prog)))
;;

let run_ocaml_source_program_capturing_stdout_lines
      build_config
      builtin_modules
      ~source_path
      ~extra_compile_args
      ~extra_link_args
      ~args
  =
  with_built_ocaml_program_command
    build_config
    builtin_modules
    ~source_path
    ~keep_artifacts:false
    ~extra_compile_args
    ~extra_link_args
    ~args
    ~f:(fun command ->
      Process.Blocking.run_command_capturing_stdout_lines command
      |> Process.Blocking.valued_result_to_user_result)
;;
