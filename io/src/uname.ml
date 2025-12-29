open! Alice_stdlib
open Alice_error

let run_uname env args =
  let command = Command.create "uname" ~args env in
  match Process.Blocking.run_command_capturing_stdout_lines command with
  | Ok ({ status = Process.Status.Exited 0; _ }, [ output ]) -> output
  | Ok ({ status = Process.Status.Exited 0; _ }, []) ->
    panic
      [ Pp.textf "No output from %s" (Command.to_string_ignore_env_backticks command) ]
  | Ok ({ status = Process.Status.Exited 0; _ }, _) ->
    panic
      [ Pp.textf
          "Multiple lines output from %s expectedly"
          (Command.to_string_ignore_env_backticks command)
      ]
  | _ ->
    panic [ Pp.textf "Failed to run %s" (Command.to_string_ignore_env_backticks command) ]
;;

let uname env arg =
  match arg with
  | `M -> run_uname env [ "-m" ]
  | `S -> run_uname env [ "-s" ]
;;
