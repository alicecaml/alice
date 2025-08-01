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
    ]
  |> run ~program_name:(Literal "alice")
;;
