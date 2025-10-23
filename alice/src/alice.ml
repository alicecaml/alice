open Climate
module Tools = Tools

let command =
  let open Command in
  group
    ~doc:"Alice is a build system for OCaml projects."
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
  match Command.run command ~program_name:(Literal "alice") with
  | () -> ()
  | exception Alice_error.User_error.E error ->
    Alice_error.User_error.eprint (error @ [ Pp.newline ]);
    exit 1
;;
