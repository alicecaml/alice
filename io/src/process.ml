open! Alice_stdlib
open Alice_hierarchy

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

  let run_capturing_stdout_lines ?(stdin = Unix.stdin) ?(stderr = Unix.stderr) prog ~args =
    Temp_dir.with_ ~prefix:"alice." ~suffix:".stdout" ~f:(fun dir ->
      let path = Path.concat dir (Path.relative "stdout") in
      let perms = 0o755 in
      let output_file_desc =
        Unix.openfile (Path.to_filename path) [ O_CREAT; O_RDWR ] perms
      in
      let result = run ~stdin ~stdout:output_file_desc ~stderr prog ~args in
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
    =
    run ~stdin ~stdout ~stderr prog ~args
  ;;

  let run_command_capturing_stdout_lines
        ?(stdin = Unix.stdin)
        ?(stderr = Unix.stderr)
        { Command.prog; args }
    =
    run_capturing_stdout_lines ~stdin ~stderr prog ~args
  ;;
end
