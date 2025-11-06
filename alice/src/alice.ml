open! Alice_stdlib
open Climate
module Tools = Tools

module Version = struct
  open Alice_package_meta.Semantic_version

  let version () =
    match of_string "0.1.0-dev" with
    | Ok v -> v
    | Error e ->
      Alice_error.User_error.eprint e;
      exit 1
  ;;

  let string () = to_string_v (version ())
end

let command =
  let default_arg_parser =
    let open Arg_parser in
    let+ version = flag [ "version" ] ~doc:"Print the version and exit." in
    if version then print_endline (sprintf "Alice %s" (Version.string ()))
  in
  let open Command in
  group
    ~doc:"Alice is a build system for OCaml projects."
    ~default_arg_parser
    [ Build.subcommand
    ; Clean.subcommand
    ; Dot.subcommand
    ; New.subcommand
    ; Tools.subcommand
    ; Run.subcommand
    ; subcommand "help" help
    ; Internal.subcommand
    ]
;;

Internal.command_for_completion_script := Some command

let () =
  match
    Command.run command ~program_name:(Literal "alice") ~version:(Version.string ())
  with
  | () -> ()
  | exception Alice_error.User_error.E error ->
    Alice_error.User_error.eprint (error @ [ Pp.newline ]);
    exit 1
;;
