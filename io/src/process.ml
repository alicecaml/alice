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
end

module Report = struct
  type t =
    { status : Status.t
    ; command : Command.t
    }

  let format_exit_code exit_code =
    let os_type = Alice_env.Os_type.current () in
    if Alice_env.Os_type.is_windows os_type
    then (
      (* Return the last 8 digits of the hex representation of the exit code.
         Exit codes in Windows are unsigned 32-bit integers. Note that this
         code will misbehave on 32-bit machines but Alice isn't supported on
         32-bit Windows. *)
      let s = sprintf "%X" exit_code in
      let length = String.length s in
      if length <= 8 then s else String.sub s ~pos:(length - 8) ~len:8)
    else sprintf "%d" exit_code
  ;;

  let error_unless_exit_0 t =
    let error message =
      Alice_error.user_exn
        [ Pp.textf
            "Tried to run command %s"
            (Command.to_string_ignore_env_backticks t.command)
        ; Pp.text "... but it exited unexpectedly for the following reason:"
        ; Pp.newline
        ; message
        ]
    in
    match t.status with
    | Exited 0 -> ()
    | Exited x ->
      error (Pp.textf "Process exited with non-zero status: %s" (format_exit_code x))
    | Signaled x -> error (Pp.textf "Process exited due to an unhandled signal: %d" x)
    | Stopped x -> error (Pp.textf "Process was stopped by a signal: %d" x)
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
    let env_arr = Env.to_raw env in
    let args_arr = Array.of_list (prog :: args) in
    try
      Log.debug
        [ Pp.textf "Running command: %s" (String.concat ~sep:" " (Array.to_list args_arr))
        ];
      let pid = Unix.create_process_env prog args_arr env_arr stdin stdout stderr in
      let _, status = Unix.waitpid [] pid in
      Ok { Report.status = Status.of_unix status; command = { Command.prog; args; env } }
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
        { Command.prog; args; env }
    =
    run ~stdin ~stdout ~stderr prog ~args ~env
  ;;

  let run_command_capturing_stdout_lines
        ?(stdin = Unix.stdin)
        ?(stderr = Unix.stderr)
        { Command.prog; args; env }
    =
    run_capturing_stdout_lines ~stdin ~stderr prog ~args ~env
  ;;
end

module Eio = struct
  let run proc_mgr prog ~args ~env =
    let env_arr = Env.to_raw env in
    Log.debug [ Pp.textf "Running command: %s %s" prog (String.concat ~sep:" " args) ];
    let stderr_buffer = Buffer.create 0 in
    let stderr = Eio.Flow.buffer_sink stderr_buffer in
    try Eio.Process.run ~stderr proc_mgr ~env:env_arr ~executable:prog args with
    | Eio.Io _ ->
      let stderr_string = String.of_bytes (Buffer.to_bytes stderr_buffer) in
      Alice_error.user_exn [ Pp.textf "%s" stderr_string ]
  ;;

  let run_command proc_mgr { Command.prog; args; env } = run proc_mgr prog ~args ~env
end
