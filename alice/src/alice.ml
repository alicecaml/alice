open Climate

let up =
  let open Arg_parser in
  let+ () = const () in
  print_endline "todo"
;;

let () =
  let open Command in
  group
    [ subcommand
        "up"
        (singleton up ~doc:"Install a compiler toolchain and accompanying tools.")
    ]
  |> run ~program_name:(Literal "alice")
;;
