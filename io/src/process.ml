open! Alice_stdlib
open Alice_hierarchy
open Alice_env
module Log = Alice_log

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

  let panic_unless_exit_0 = function
    | Exited 0 -> ()
    | Exited x ->
      Alice_error.panic [ Pp.textf "Process exited with non-zero status: %d" x ]
    | Signaled x ->
      Alice_error.panic [ Pp.textf "Process exited due to an unhandled signal: %d" x ]
    | Stopped x -> Alice_error.panic [ Pp.textf "Process was stopped by a signal: %d" x ]
  ;;
end

module Env_setting = struct
  type t =
    [ `Inherit
    | `Env of Env.t
    ]
end

module Blocking = struct
  let run
        ?(env = `Inherit)
        ?(stdin = Unix.stdin)
        ?(stdout = Unix.stdout)
        ?(stderr = Unix.stderr)
        prog
        ~args
    =
    let env =
      match env with
      | `Inherit -> Env.current ()
      | `Env env -> env
    in
    let env = Env.to_raw env in
    let env = Array.to_list env in
    (*print_endline (sprintf "%s" (Dyn.list Dyn.string env |> Dyn.to_string)); *)
    let env = Array.of_list env in
    let args = Array.of_list (prog :: args) in
    try
      Log.debug
        [ Pp.textf "Running command: %s" (String.concat ~sep:" " (Array.to_list args)) ];
      let pid = Unix.create_process_env prog args env stdin stdout stderr in
      let _, status = Unix.waitpid [] pid in
      Ok (Status.of_unix status)
    with
    | Unix.Unix_error (Unix.ENOENT, _, _) -> Error `Prog_not_available
  ;;

  let run_capturing_stdout_lines
        ?env
        ?(stdin = Unix.stdin)
        ?(stderr = Unix.stderr)
        prog
        ~args
    =
    Temp_dir.with_ ~prefix:"alice." ~suffix:".stdout" ~f:(fun dir ->
      let path = Path.concat dir (Path.relative "stdout") in
      let perms = 0o755 in
      let output_file_desc =
        Unix.openfile (Path.to_filename path) [ O_CREAT; O_RDWR ] perms
      in
      let result = run ?env ~stdin ~stdout:output_file_desc ~stderr prog ~args in
      let result =
        Result.map result ~f:(fun status ->
          let _ = Unix.lseek output_file_desc 0 SEEK_SET in
          let channel = Unix.in_channel_of_descr output_file_desc in
          let lines = In_channel.input_lines channel in
          status, lines)
      in
      Unix.close output_file_desc;
      result)
  ;;

  let run_command
        ?env
        ?(stdin = Unix.stdin)
        ?(stdout = Unix.stdout)
        ?(stderr = Unix.stderr)
        { Command.prog; args }
    =
    run ?env ~stdin ~stdout ~stderr prog ~args
  ;;

  let run_command_capturing_stdout_lines
        ?env
        ?(stdin = Unix.stdin)
        ?(stderr = Unix.stderr)
        { Command.prog; args }
    =
    run_capturing_stdout_lines ?env ~stdin ~stderr prog ~args
  ;;
end
