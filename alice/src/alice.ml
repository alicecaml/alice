open Climate
module Tools = Tools

let up =
  let open Arg_parser in
  let+ () = const () in
  print_endline "todo"
;;

let () =
  let open Command in
  group
    [ subcommand
        "tools"
        (singleton up ~doc:"Commands for managing installation of development tools.")
    ]
  |> run
;;
