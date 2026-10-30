let () =
  Array.iteri (fun i arg -> print_endline (Printf.sprintf "arg %d: %s" i arg)) Sys.argv;
  match Sys.getenv_opt "FOO" with
  | None -> print_endline "env var \"FOO\" is unset"
  | Some value -> print_endline (Printf.sprintf "FOO = %S" value)
;;
