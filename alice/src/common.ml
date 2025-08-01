open! Alice_stdlib
open Alice_hierarchy
open Alice_error
open Alice_project
module File_ops = Alice_io.File_ops
open Climate

let cwd () = Path.absolute (Sys.getcwd ())

let parse_manifest_path_opt =
  let open Arg_parser in
  named_opt
    [ "manifest-path" ]
    file
    ~doc:
      (sprintf
         "Read project metadata from this file instead of %s."
         Project.manifest_name)
;;

let parse_absolute_path ?doc names =
  let open Arg_parser in
  let+ path = named_opt names file ?doc in
  Option.map path ~f:(fun path_str ->
    match Path.of_filename path_str with
    | `Absolute p -> p
    | `Relative p -> Path.concat (cwd ()) p)
;;

let parse_manifest_path_and_validate =
  let open Arg_parser in
  let+ manifest_path = parse_manifest_path_opt in
  match manifest_path with
  | Some manifest_path_str ->
    let absolute_path =
      match Path.of_filename manifest_path_str with
      | `Absolute p -> p
      | `Relative p -> Path.concat (cwd ()) p
    in
    (match File_ops.exists absolute_path with
     | true -> absolute_path
     | false ->
       user_error
         [ Pp.text "Can't find file passed to --manifest-path.\n"
         ; Pp.textf "%S does not exist." (Path.to_filename absolute_path)
         ])
  | None ->
    let path = Path.concat (cwd ()) (Path.relative Project.manifest_name) in
    (match File_ops.exists path with
     | true -> path
     | false ->
       user_error
         [ Pp.textf
             "This command must be run from a directory containing a file named %S.\n"
             Project.manifest_name
         ; Pp.textf "The file %S does not exist.\n" (Path.to_filename path)
         ; Pp.text
             "Alternatitvely, pass the location of a metadata file with --metadata-path."
         ])
;;

let parse_project =
  let open Arg_parser in
  let+ manifest_path = parse_manifest_path_and_validate in
  Project.create
    ~root:(Path.dirname manifest_path)
    ~manifest:(Alice_manifest.Io.read_project manifest_path)
;;

let parse_ctx =
  let open Arg_parser in
  let+ release = flag [ "release" ] ~doc:"Build with optimizations." in
  match release with
  | true -> Alice_policy.Ocaml.Ctx.release
  | false -> Alice_policy.Ocaml.Ctx.debug
;;
