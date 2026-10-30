open! Alice_stdlib
open Alice_hierarchy
open Alice_error
open Alice_engine
open Alice_ocaml_toolchain
module File_ops = Alice_io.File_ops
open Climate

let parse_manifest_path_opt =
  let open Arg_parser in
  named_opt
    [ "m"; "manifest-path" ]
    file
    ~doc:
      (sprintf
         "Read project metadata from FILE instead of %s."
         (Basename.to_filename Alice_manifest.manifest_name))
;;

let string_to_absolute_path path_str =
  match Either_path.of_filename path_str with
  | `Absolute p -> p
  | `Relative p ->
    Absolute_path.Root_or_non_root.concat_relative_exn Alice_env.initial_cwd p
;;

let string_to_absolute_path_non_root path_str =
  match string_to_absolute_path path_str with
  | `Root path ->
    user_exn
      [ Pp.textf
          "Got path %S but root directory is not allowed here."
          (Absolute_path.to_filename path)
      ]
  | `Non_root path -> path
;;

let parse_absolute_path ?doc names =
  let open Arg_parser in
  let+ path = named_opt names file ?doc ~value_name:"PATH" in
  Option.map path ~f:string_to_absolute_path
;;

let parse_manifest_path_and_validate =
  let open Arg_parser in
  let+ manifest_path = parse_manifest_path_opt in
  match manifest_path with
  | Some manifest_path_str ->
    let absolute_path =
      let root_error p =
        user_exn
          [ Pp.textf
              "The manifest path %S was specified, but this is a root directory which is \
               not allowed."
              (Absolute_path.to_filename p)
          ]
      in
      match Either_path.of_filename manifest_path_str with
      | `Absolute (`Non_root p) -> p
      | `Absolute (`Root p) -> root_error p
      | `Relative p ->
        (match
           Absolute_path.Root_or_non_root.concat_relative_exn Alice_env.initial_cwd p
         with
         | `Non_root p -> p
         | `Root p -> root_error p)
    in
    (match File_ops.exists absolute_path with
     | true ->
       if
         Basename.equal
           (Absolute_path.basename absolute_path)
           Alice_manifest.manifest_name
       then absolute_path
       else
         user_exn
           [ Pp.textf
               "Expected path passed to --manifest-path to have basename %S, but got %S."
               (Basename.to_filename Alice_manifest.manifest_name)
               manifest_path_str
           ]
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
         ; Pp.textf
             "The file %S does not exist.\n"
             (Alice_ui.absolute_path_to_string path)
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
  let+ release = flag [ "r"; "release" ] ~doc:"Build with optimizations." in
  match release with
  | true -> Profile.release
  | false -> Profile.debug
;;

let parse_compiler_backend ~default =
  let open Arg_parser in
  let conv =
    enum
      ~default_value_name:"BACKEND"
      ~eq:Compiler_backend.equal
      (List.map [ Compiler_backend.Native; Compiler_backend.Bytecode ] ~f:(fun backend ->
         Compiler_backend.name backend, backend))
  in
  named_with_default
    [ "b"; "backend" ]
    ~default
    conv
    ~doc:
      (sprintf
         "Which compiler backend to use (\"native\" or \"bytecode\"). Defaults to %S."
         (Compiler_backend.name default))
;;

let parse_built_artifacts_from_deps =
  let open Arg_parser in
  flag
    [ "built-artifacts-from-deps" ]
    ~hidden:true
    ~doc:
      "Expect dependencies to contain built artifacts and use them rather than builting \
       each dependency in the current project's build directory. Intended to be used \
       when building each package in a repository to avoid unnecessary rebuilds."
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
  let+ quiet = flag [ "quiet"; "q" ] ~doc:"Suppress printing of progress messages." in
  if quiet then Alice_ui.set_mode `Quiet
;;

let set_normalized_paths_from_flag =
  let open Arg_parser in
  let+ normalized_paths =
    flag
      [ "normalize-paths" ]
      ~doc:"Always use '/' as path separator in messages."
      ~hidden:true
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

let parse_num_jobs =
  let open Alice_io in
  let open Arg_parser in
  let+ jobs =
    named_opt [ "j"; "jobs" ] int ~doc:"Limit the number of parallel jobs to INT."
  in
  match jobs with
  | None -> Num_jobs.unlimited
  | Some n -> Num_jobs.limited n
;;

let parse_debug_blocking_subprocesses =
  let open Arg_parser in
  flag
    [ "debug-blocking-subprocesses" ]
    ~doc:"Don't use eio to spawn processes"
    ~hidden:true
;;

let parse_build_config ~default_compiler_backend =
  let open Arg_parser in
  let+ profile = parse_profile
  and+ compiler_backend = parse_compiler_backend ~default:default_compiler_backend
  and+ num_jobs = parse_num_jobs in
  let env = Alice_env.current_env () in
  let os_type = Alice_env.Os_type.current () in
  let ocaml_toolchain = Alice_which.ocaml_toolchain os_type env in
  { Build_config.profile; ocaml_toolchain; compiler_backend; num_jobs; os_type }
;;
