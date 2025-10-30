open! Alice_stdlib
open Alice_hierarchy
open Climate
module File_ops = Alice_io.File_ops
open Alice_error
open Alice_package

let make_project name path kind =
  let src = Package.default_src in
  let manifest_path = Path.relative Alice_manifest.manifest_name in
  if File_ops.exists (path / manifest_path)
  then
    user_exn
      [ Pp.textf
          "Refusing to create project because destination directory exists and contains \
           project manifest (%s).\n"
          (Alice_ui.path_to_string (path / manifest_path))
      ; Pp.text "Delete this file before proceeding."
      ];
  if File_ops.exists (path / src)
  then
    if File_ops.is_directory (path / src)
    then
      user_exn
        [ Pp.textf
            "Refusing to create project because destination directory exists and \
             contains src directory (%s).\n"
            (Alice_ui.path_to_string (path / src))
        ; Pp.text "Delete this directory before proceeding."
        ]
    else
      user_exn
        [ Pp.textf
            "Refusing to create project because destination directory exists and \
             contains a file named \"src\" (%s).\n"
            (Alice_ui.path_to_string (path / src))
        ; Pp.text "Delete this file before proceeding."
        ];
  let manifest =
    Package_meta.create
      ~id:
        { name
        ; version = Semantic_version.of_string_res "0.1.0" |> User_error.get_or_panic
        }
      ~dependencies:None
  in
  File_ops.mkdir_p (path / src);
  File_ops.write_text_file
    (path / Path.relative ".gitignore")
    (Path.to_filename Alice_engine.Project.build_dir_path_relative_to_project_root);
  Alice_manifest.write_package_manifest ~manifest_path:(path / manifest_path) manifest;
  match kind with
  | `Exe ->
    File_ops.write_text_file
      (path / src / Package.default_exe_root_ml)
      "let () = print_endline \"Hello, World!\""
  | `Lib ->
    File_ops.write_text_file
      (path / src / Package.default_lib_root_ml)
      "let add lhs rhs = lhs + rhs"
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
    | None -> Path.concat (Path.absolute (Sys.getcwd ())) (Path.relative name)
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
  println
    (verb_message
       `Creating
       (sprintf "new %s package %S in %s" kind_string name (Alice_ui.path_to_string path)));
  make_project package_name path kind;
  print_newline ()
;;

let subcommand =
  let open Command in
  subcommand "new" ~aliases:[ "n" ] (singleton ~doc:"Create a new alice project." new_)
;;
