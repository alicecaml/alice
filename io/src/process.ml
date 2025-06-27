open! Alice_stdlib

module Status = struct
  type t =
    | Exited of int
    | Signaled of int
    | Stopped of int

  let to_dyn t =
    match (t : t) with
    | Exited x -> Dyn.variant "Exited" [ Dyn.int x ]
    | Signaled x -> Dyn.variant "Signaled" [ Dyn.int x ]
    | Stopped x -> Dyn.variant "Stopped" [ Dyn.int x ]
  ;;

  let of_unix (process_status : Unix.process_status) =
    match process_status with
    | WEXITED x -> Exited x
    | WSIGNALED x -> Signaled x
    | WSTOPPED x -> Stopped x
  ;;
end

module Blocking = struct
  let run ?(stdin = Unix.stdin) ?(stdout = Unix.stdout) ?(stderr = Unix.stderr) prog ~args
    =
    let args = Array.of_list (prog :: args) in
    try
      let pid = Unix.create_process prog args stdin stdout stderr in
      let _, status = Unix.waitpid [] pid in
      Ok (Status.of_unix status)
    with
    | Unix.Unix_error (Unix.ENOENT, _, _) -> Error `Prog_not_available
  ;;

  let run_command
        ?(stdin = Unix.stdin)
        ?(stdout = Unix.stdout)
        ?(stderr = Unix.stderr)
        { Command.prog; args }
    =
    run ~stdin ~stdout ~stderr prog ~args
  ;;
end
