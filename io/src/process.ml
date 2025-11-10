open! Alice_stdlib
open Alice_hierarchy
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

module Blocking = struct
  let run
        ?(stdin = Unix.stdin)
        ?(stdout = Unix.stdout)
        ?(stderr = Unix.stderr)
        prog
        ~args
        ~env
    =
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
        ?(stdin = Unix.stdin)
        ?(stderr = Unix.stderr)
        prog
        ~args
        ~env
    =
    Temp_dir.with_ ~prefix:"alice." ~suffix:".stdout" ~f:(fun dir ->
      let path = dir / Basename.of_filename "stdout" in
      let perms = 0o755 in
      let output_file_desc =
        Unix.openfile (Absolute_path.to_filename path) [ O_CREAT; O_RDWR ] perms
      in
      let result = run ~stdin ~stdout:output_file_desc ~stderr prog ~args ~env in
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
        ?(stdin = Unix.stdin)
        ?(stdout = Unix.stdout)
        ?(stderr = Unix.stderr)
        { Command.prog; args }
        ~env
    =
    run ~stdin ~stdout ~stderr prog ~args ~env
  ;;

  let run_command_capturing_stdout_lines
        ?(stdin = Unix.stdin)
        ?(stderr = Unix.stderr)
        { Command.prog; args }
        ~env
    =
    run_capturing_stdout_lines ~stdin ~stderr prog ~args ~env
  ;;
end
