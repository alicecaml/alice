open! Alice_stdlib
open Alice_project
open Alice_hierarchy
open Climate

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
  let package_name = Alice_manifest.Package_name.of_string name in
  let path =
    match path with
    | Some path -> path
    | None -> Path.concat (Path.absolute (Sys.getcwd ())) (Path.relative name)
  in
  let kind =
    match exe, lib with
    | false, false | true, false -> `Exe
    | false, true -> `Lib
    | true, true ->
      Alice_error.user_error [ Pp.text "Can't specify both --exe and --lib" ]
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
  Project.new_ocaml package_name path kind;
  print_newline ()
;;

let subcommand =
  let open Command in
  subcommand "new" ~aliases:[ "n" ] (singleton ~doc:"Create a new alice project." new_)
;;
