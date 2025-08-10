open Climate
module Tools = Tools

let () =
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
    ; subcommand
        "internal"
        (group
           ~doc:"Internal commands."
           [ subcommand
               "completions"
               (group
                  ~doc:"Generate a completion script for Alice."
                  [ subcommand "bash" print_completion_script_bash ])
           ])
    ]
  |> run ~program_name:(Literal "alice")
;;
