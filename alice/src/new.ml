open! Alice_stdlib
open Alice_project
open Alice_hierarchy
open Climate

let new_ =
  let open Arg_parser in
  let+ name = pos_req 0 string ~doc:"Name of the project"
  and+ path =
    Common.parse_absolute_path
      ~doc:"Initialize the new project in this directory (must not already exist)"
      [ "path"; "p" ]
  in
  let package_name = Alice_manifest.Package_name.of_string_exn name in
  let path =
    match path with
    | Some path -> path
    | None -> Path.concat (Path.absolute (Sys.getcwd ())) (Path.relative name)
  in
  Project.new_ocaml_exe package_name path
;;

let subcommand =
  let open Command in
  subcommand "new" (singleton ~doc:"Create a new alice project." new_)
;;
