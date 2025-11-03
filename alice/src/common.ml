open! Alice_stdlib
open Alice_hierarchy
open Alice_error
open Alice_engine
module File_ops = Alice_io.File_ops
open Climate

let parse_manifest_path_opt =
  let open Arg_parser in
  named_opt
    [ "manifest-path" ]
    file
    ~doc:
      (sprintf
         "Read project metadata from FILE instead of %s."
         (Basename.to_filename Alice_manifest.manifest_name))
;;

let parse_absolute_path ?doc names =
  let open Arg_parser in
  let+ path = named_opt names file ?doc ~value_name:"PATH" in
  Option.map path ~f:(fun path_str ->
    match Either_path.of_filename path_str with
    | `Absolute p -> p
    | `Relative p ->
      `Non_root (Absolute_path.Root_or_non_root.concat_relative Alice_env.initial_cwd p))
;;

let parse_manifest_path_and_validate =
  let open Arg_parser in
  let+ manifest_path = parse_manifest_path_opt in
  match manifest_path with
  | Some manifest_path_str ->
    let absolute_path =
      match Either_path.of_filename manifest_path_str with
      | `Absolute (`Non_root p) -> p
      | `Absolute (`Root p) ->
        user_exn
          [ Pp.textf
              "The manifest path %S was specified, but this is a root directory which is \
               not allowed."
              (Absolute_path.to_filename p)
          ]
      | `Relative p ->
        Absolute_path.Root_or_non_root.concat_relative Alice_env.initial_cwd p
    in
    (match File_ops.exists absolute_path with
     | true -> absolute_path
     | false ->
       user_exn
         [ Pp.text "Can't find file passed to --manifest-path.\n"
         ; Pp.textf "%S does not exist." (Absolute_path.to_filename absolute_path)
         ])
  | None ->
    let path =
      Absolute_path.Root_or_non_root.concat_basename
        Alice_env.initial_cwd
        Alice_manifest.manifest_name
    in
    (match File_ops.exists path with
     | true -> path
     | false ->
       user_exn
         [ Pp.textf
             "This command must be run from a directory containing a file named %S.\n"
             (Basename.to_filename Alice_manifest.manifest_name)
         ; Pp.textf "The file %S does not exist.\n" (Alice_ui.path_to_string path)
         ; Pp.text
             "Alternatitvely, pass the location of a metadata file with --metadata-path."
         ])
;;

let parse_project =
  let open Arg_parser in
  let+ manifest_path = parse_manifest_path_and_validate in
  Alice_package.Package.read_root (Absolute_path.parent manifest_path)
  |> Project.of_package
;;

let parse_profile =
  let open Arg_parser in
  let+ release = flag [ "release" ] ~doc:"Build with optimizations." in
  match release with
  | true -> Profile.release
  | false -> Profile.debug
;;

let set_log_level_from_verbose_flag =
  let open Arg_parser in
  let+ verbosity =
    flag_count [ "verbose"; "v" ] ~doc:"Enable verbose output (-vv for extra verbosity)."
  in
  let log_level =
    match verbosity with
    | 0 -> `Warn
    | 1 -> `Info
    | _ -> `Debug
  in
  Alice_log.set_level log_level
;;

let set_print_mode_from_quiet_flag =
  let open Arg_parser in
  let+ quiet = flag [ "quiet"; "q" ] ~doc:"Supress printing of progress messages." in
  if quiet then Alice_ui.set_mode `Quiet
;;

let set_normalized_paths_from_flag =
  let open Arg_parser in
  let+ normalized_paths =
    flag [ "normalize-paths" ] ~doc:"Always use '/' as path separator in messages."
  in
  if normalized_paths then Alice_ui.set_normalized_paths ()
;;

let set_globals_from_flags =
  let open Arg_parser in
  let+ () = set_log_level_from_verbose_flag
  and+ () = set_print_mode_from_quiet_flag
  and+ () = set_normalized_paths_from_flag in
  ()
;;
