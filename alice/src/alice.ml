open! Alice_stdlib
open Climate
module Tools = Tools

let version = "0.3.0"

let command =
  let tagline = "Alice is a build system for OCaml projects." in
  let default_arg_parser =
    let open Arg_parser in
    let+ version_ = flag [ "version" ] ~doc:"Print the version and exit." in
    if version_
    then print_endline (sprintf "Alice %s" version)
    else (
      print_endline
        (sprintf
           {|%s

Run `alice --help` for usage information.|}
           tagline);
      exit 1)
  in
  let open Command in
  group
    ~doc:tagline
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
  let help_style =
    let open Help_style in
    { default with margin = Some 100 }
  in
  match Command.run command ~program_name:(Literal "alice") ~version ~help_style with
  | () -> ()
  | exception Alice_error.User_error.E error ->
    Alice_error.User_error.eprint (error @ [ Pp.newline ]);
    exit 1
;;
