open! Alice_stdlib
open Alice_package
open Alice_error
open Alice_hierarchy
open Alice_ui
module Package_base_dir = Build_dir.Package_base_dir
module Builtin_module = Alice_builtin_module
module Gen_file = Op.Gen_file
module File_ops = Alice_io.File_ops
module Log = Alice_log

(* Build and run the config script, returning the lines it printed to stdout. *)
let run_config_script
      build_dir
      build_config
      package_meta
      ~config_script_dependency_graph
      ~config_script_source_path
  =
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
  | Ok lines -> lines
;;

let output_basename = Basename.of_filename "config_script.out"

module Directive = struct
  (* Lines beginning with "alice:" denote directives. A directive has a name
     followed by whitespace separated arguments. *)
  type t =
    (* Print the argument followed by a newline. *)
    | Print_line of string
    (* Extra arguments to pass to the linker. Each argument will be passed like
       "-cclib <arg1> -cclib <arg2>...". *)
    | Add_c_linker_args of string list

  let at_least_one_space = lazy (Re.compile @@ Re.rep1 Re.space)

  let parse directive_string =
    let parse_print_line arg = Ok (Print_line arg) in
    let parse_add_c_linker_args arg =
      Ok (Add_c_linker_args (Re.split (Lazy.force at_least_one_space) arg))
    in
    let all_directive_parsers =
      [ "print_line:", parse_print_line; "add_c_linker_args:", parse_add_c_linker_args ]
    in
    match
      List.find_map all_directive_parsers ~f:(fun (prefix, parse) ->
        String.drop_prefix directive_string ~prefix |> Option.map ~f:parse)
    with
    | Some directive -> directive
    | None ->
      Error
        [ Pp.textf "Failed to parse directive %S." directive_string
        ; Pp.newline
        ; Pp.newline
        ; Pp.textf "Valid directives must start with one of:"
        ; Pp.newline
        ; Pp.enumerate all_directive_parsers ~f:(fun (prefix, _) -> Pp.textf "%s" prefix)
        ]
  ;;

  let of_line_opt line = String.drop_prefix line ~prefix:"alice:" |> Option.map ~f:parse
  let multi_of_lines lines = List.filter_map lines ~f:of_line_opt |> Result.List.all
end

module Output = struct
  type t =
    { lines_to_print : string list
    ; c_linker_args : string list
    }

  let default = { lines_to_print = []; c_linker_args = [] }

  let of_lines lines =
    let open Result.O in
    let+ directives = Directive.multi_of_lines lines in
    let with_lists_reversed =
      List.fold_left directives ~init:default ~f:(fun acc directive ->
        match (directive : Directive.t) with
        | Add_c_linker_args c_linker_args ->
          { acc with c_linker_args = c_linker_args @ acc.c_linker_args }
        | Print_line line -> { acc with lines_to_print = line :: acc.lines_to_print })
    in
    { lines_to_print = List.rev with_lists_reversed.lines_to_print
    ; c_linker_args = List.rev with_lists_reversed.c_linker_args
    }
  ;;
end

let run
      build_dir
      package_meta
      ~package_build_config
      ~config_script_build_config
      ~config_script_dependency_graph
      ~config_script_source_path
      ~any_dep_built
  =
  let base_dir =
    Build_dir.package_base_dir_of_build_config
      build_dir
      (Package_meta.id package_meta)
      package_build_config
  in
  let output_path = Package_base_dir.path base_dir / output_basename in
  let need_to_rebuild =
    Built_status.is_built any_dep_built
    || (not (File_ops.exists output_path))
    || File_ops.mtime config_script_source_path > File_ops.mtime output_path
  in
  let lines, built_status =
    if need_to_rebuild
    then (
      println
        (verb_message
           `Configuring
           (Package_id.name_v_version_string (Package_meta.id package_meta)));
      Log.info
        ~package_id:(Package_meta.id package_meta)
        [ Pp.textf
            "Running config script storing output in %s"
            (Absolute_path.to_filename output_path)
        ];
      let lines =
        run_config_script
          build_dir
          config_script_build_config
          package_meta
          ~config_script_dependency_graph
          ~config_script_source_path
      in
      File_ops.mkdir_p (Package_base_dir.path base_dir);
      File_ops.write_text_file output_path (String.concat ~sep:"\n" lines);
      lines, Built_status.Built)
    else (
      Log.info
        ~package_id:(Package_meta.id package_meta)
        [ Pp.textf
            "Loading existing config script output from %s"
            (Absolute_path.to_filename output_path)
        ];
      let lines = File_ops.read_text_file output_path |> String.split_on_char ~sep:'\n' in
      lines, Built_status.Reused)
  in
  match Output.of_lines lines with
  | Error e ->
    user_exn
      ([ Pp.text "Failed to parse config script output!"; Pp.newline; Pp.newline ]
       @ e
       @ [ Pp.newline
         ; Pp.newline
         ; Pp.textf
             "The config script is at: %s"
             (Absolute_path.to_filename config_script_source_path)
         ; Pp.newline
         ; Pp.newline
         ; Pp.textf
             "The full config script output is at: %s"
             (Absolute_path.to_filename output_path)
         ])
  | Ok output -> output, built_status
;;
