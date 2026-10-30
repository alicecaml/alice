open! Alice_stdlib
open Alice_package
open Alice_error
open Alice_hierarchy
open Alice_ui
module Package_base_dir = Build_dir.Package_base_dir
module Builtin_module = Alice_builtin_module
module Gen_file = Op.Gen_file

let run
      build_dir
      build_config
      package_meta
      ~config_script_dependency_graph
      ~config_script_source_path
      ~any_dep_rebuilt
  =
  let _todo =
    (* TODO: Only rerun the configure script if its cached output is older than
       the script, or any dep has been rebuilt this run. *)
    any_dep_rebuilt
  in
  let config_script_meta = Package_meta.config_script package_meta in
  let builtin_modules =
    Package_meta.Config_script_meta.builtin_modules config_script_meta
  in
  let transitive_dep_libs =
    Dependency_graph.transitive_dependency_closure_in_dependency_order
      config_script_dependency_graph
    |> List.map ~f:Dependency_graph.Package_with_deps.package
  in
  let immediate_dep_libs =
    Dependency_graph.roots config_script_dependency_graph
    |> List.map ~f:Dependency_graph.Package_with_deps.package
  in
  let open_ =
    List.concat_map immediate_dep_libs ~f:(fun dep_lib ->
      let module_name = Package.name dep_lib |> Module_name.public_interface_to_open in
      [ "-open"; Module_name.to_string_uppercase_first_letter module_name ])
  in
  let include_ =
    List.concat_map transitive_dep_libs ~f:(fun dep_lib ->
      let package_id = Package.id dep_lib in
      let public =
        Build_dir.package_base_dir_of_build_config build_dir package_id build_config
        |> Package_base_dir.public_dir
      in
      [ "-I"; Absolute_path.to_filename public ])
  in
  let ocaml_archive_files =
    List.map transitive_dep_libs ~f:(fun dep_lib ->
      let package_id = Package.id dep_lib in
      let public =
        Build_dir.package_base_dir_of_build_config build_dir package_id build_config
        |> Package_base_dir.public_dir
      in
      let archive =
        Gen_file.lib_ocaml_archive_file build_config.compiler_backend |> Gen_file.path
      in
      Absolute_path.to_filename (public / archive))
  in
  let package_has_c_code package =
    let src_dir = Package.src_dir_exn package in
    List.exists src_dir.contents ~f:(fun (file : File_non_root.t) ->
      Absolute_path.has_extension file.path ~ext:".c")
  in
  let custom_linker_args_for_bytecode_backend =
    match build_config.compiler_backend with
    | Native -> []
    | Bytecode ->
      (* Bytecode executables must be linked with "-custom" if there is
         any C code in the package or among the transitive closure of the
         package's dependencies. *)
      let c_code_in_transitive_closure =
        List.exists transitive_dep_libs ~f:package_has_c_code
      in
      if c_code_in_transitive_closure then [ "-custom" ] else []
  in
  let extra_compile_args = open_ @ include_ in
  let extra_link_args = custom_linker_args_for_bytecode_backend @ ocaml_archive_files in
  println
    (verb_message
       `Configuring
       (Package_id.name_v_version_string (Package_meta.id package_meta)));
  let result =
    Run_ocaml_source_program.run_ocaml_source_program_capturing_stdout_lines
      build_config
      (Builtin_module.Set.to_list builtin_modules)
      ~source_path:config_script_source_path
      ~extra_compile_args
      ~extra_link_args
      ~args:[]
  in
  match result with
  | Error e ->
    user_exn
      ([ Pp.textf
           "Failed to run config script for package %S."
           (Package_meta.id package_meta |> Package_id.name_dash_version_string)
       ; Pp.newline
       ; Pp.newline
       ]
       @ e)
  | Ok lines -> List.iter lines ~f:print_endline
;;
