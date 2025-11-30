open! Alice_stdlib
open Alice_hierarchy
open Climate
module File_ops = Alice_io.File_ops
open Alice_error
open Alice_package
module Project = Alice_engine.Project

let make_project name path kind =
  let src_path = Absolute_path.Root_or_non_root.concat_basename path Package.src in
  let manifest_path =
    Absolute_path.Root_or_non_root.concat_basename path Alice_manifest.manifest_name
  in
  if File_ops.exists manifest_path
  then
    user_exn
      [ Pp.textf
          "Refusing to create project because destination directory exists and contains \
           project manifest (%s).\n"
          (Alice_ui.absolute_path_to_string manifest_path)
      ; Pp.text "Delete this file before proceeding."
      ];
  if File_ops.exists src_path
  then
    if File_ops.is_directory src_path
    then
      user_exn
        [ Pp.textf
            "Refusing to create project because destination directory exists and \
             contains src directory (%s).\n"
            (Alice_ui.absolute_path_to_string src_path)
        ; Pp.text "Delete this directory before proceeding."
        ]
    else
      user_exn
        [ Pp.textf
            "Refusing to create project because destination directory exists and \
             contains a file named %S (%s).\n"
            (Basename.to_filename Package.src)
            (Alice_ui.absolute_path_to_string src_path)
        ; Pp.text "Delete this file before proceeding."
        ];
  let manifest =
    Package_meta.create
      ~id:{ name; version = Semantic_version.of_string_exn "0.1.0" }
      ~dependencies:None
  in
  File_ops.mkdir_p src_path;
  (match kind with
   | `Exe ->
     File_ops.write_text_file
       (src_path / Package.exe_root_ml)
       "let () = print_endline \"Hello, World!\""
   | `Lib ->
     File_ops.write_text_file
       (src_path / Package.lib_root_ml)
       "let add lhs rhs = lhs + rhs");
  Alice_manifest.write_package_manifest ~manifest_path manifest;
  let project = Project.of_package (Package.read_root path) in
  Project.write_dot_merlin_initial project;
  Project.write_dot_gitignore project
;;

let new_ =
  let open Arg_parser in
  let+ () = Common.set_globals_from_flags
  and+ name = pos_req 0 string ~doc:"Name of the project" ~value_name:"NAME"
  and+ path =
    Common.parse_absolute_path
      ~doc:"Initialize the new project in this directory (must not already exist)"
      [ "path"; "p" ]
  and+ exe =
    flag [ "exe" ] ~doc:"Create a project containing an executable package (default)"
  and+ lib = flag [ "lib" ] ~doc:"Create a project containing a library package" in
  let package_name = Alice_package_meta.Package_name.of_string_exn name in
  let path =
    match path with
    | Some path -> path
    | None ->
      `Non_root
        (Absolute_path.Root_or_non_root.concat_basename
           Alice_env.initial_cwd
           (Basename.of_filename name))
  in
  let kind =
    match exe, lib with
    | false, false | true, false -> `Exe
    | false, true -> `Lib
    | true, true -> Alice_error.user_exn [ Pp.text "Can't specify both --exe and --lib" ]
  in
  let kind_string =
    match kind with
    | `Exe -> "executable"
    | `Lib -> "library"
  in
  let open Alice_ui in
  let path_string =
    match path with
    | `Root p -> absolute_path_to_string p
    | `Non_root p -> absolute_path_to_string p
  in
  println
    (verb_message
       `Creating
       (sprintf "new %s package %S in %s" kind_string name path_string));
  make_project package_name path kind
;;

let subcommand =
  let open Command in
  subcommand "new" ~aliases:[ "n" ] (singleton ~doc:"Create a new alice project." new_)
;;
