open! Alice_stdlib
open Alice_error

let run_uname env args =
  let command = Command.create "uname" ~args in
  match Process.Blocking.run_command_capturing_stdout_lines command ~env with
  | Ok (Process.Status.Exited 0, [ output ]) -> output
  | Ok (Process.Status.Exited 0, []) ->
    panic [ Pp.textf "No output from %s" (Command.to_string_backticks command) ]
  | Ok (Process.Status.Exited 0, _) ->
    panic
      [ Pp.textf
          "Multiple lines output from %s expectedly"
          (Command.to_string_backticks command)
      ]
  | _ -> panic [ Pp.textf "Failed to run %s" (Command.to_string_backticks command) ]
;;

let uname env arg =
  match arg with
  | `M -> run_uname env [ "-m" ]
  | `S -> run_uname env [ "-s" ]
;;
