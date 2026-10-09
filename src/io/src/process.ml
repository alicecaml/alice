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

  let is_exit_0 t =
    match t.status with
    | Exited 0 -> true
    | _ -> false
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

module Error = struct
  type t = [ `Prog_not_available of string ]

  let user_error = function
    | `Prog_not_available prog ->
      Alice_error.user_exn [ Pp.textf "No such program: %s" prog ]
  ;;

  let result_get_or_user_error = function
    | Ok x -> x
    | Error e -> user_error e
  ;;
end

module Running = struct
  type t =
    { pid : int
    ; command : Command.t
    }

  let wait { pid; command } =
    let _, status = Unix.waitpid [] pid in
    { Report.status = Status.of_unix status; command }
  ;;

  let poll { pid; command } =
    let pid, status = Unix.waitpid [ Unix.WNOHANG ] pid in
    if pid == 0 then None else Some { Report.status = Status.of_unix status; command }
  ;;

  let kill { pid; _ } = Unix.kill pid Sys.sigkill
end

module Running_capturing_stdout = struct
  type t =
    { running : Running.t
    ; stdio_dir_path : Absolute_path.non_root_t
    ; stdout_file_desc : Unix.file_descr
    ; active : bool ref
    }

  let assert_active t =
    if not !(t.active)
    then
      Alice_error.panic_u
        [ Pp.textf
            "Tried to wait for process after its stdio directory has been cleaned up. \
             Process was run with command: %s"
            (Command.to_string_ignore_env_backticks t.running.command)
        ]
  ;;

  let finalize_stdout_lines t =
    let _ = Unix.lseek t.stdout_file_desc 0 SEEK_SET in
    let channel = Unix.in_channel_of_descr t.stdout_file_desc in
    let lines = In_channel.input_lines channel in
    Unix.close t.stdout_file_desc;
    File_ops.rm_rf t.stdio_dir_path;
    t.active := false;
    lines
  ;;

  let wait_stdout_lines t =
    assert_active t;
    let report = Running.wait t.running in
    let lines = finalize_stdout_lines t in
    report, lines
  ;;

  let poll_stdout_lines t =
    assert_active t;
    Option.map (Running.poll t.running) ~f:(fun report ->
      let lines = finalize_stdout_lines t in
      report, lines)
  ;;
end

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
      [ Pp.textf "Running command: %s" (String.concat ~sep:" " (Array.to_list args_arr)) ];
    let pid = Unix.create_process_env prog args_arr env_arr stdin stdout stderr in
    Ok { Running.pid; command = { Command.prog; args; env } }
  with
  | Unix.Unix_error (Unix.ENOENT, _, _) -> Error (`Prog_not_available prog)
;;

let run_capturing_stdout ?(stdin = Unix.stdin) ?(stderr = Unix.stderr) prog ~args ~env =
  let stdio_dir_path = Temp_dir.make ~prefix:"alice." ~suffix:".stdio" in
  let stdout_file_path = stdio_dir_path / Basename.of_filename "stdout" in
  let perms = 0o755 in
  let stdout_file_desc =
    Unix.openfile (Absolute_path.to_filename stdout_file_path) [ O_CREAT; O_RDWR ] perms
  in
  match run ~stdin ~stdout:stdout_file_desc ~stderr prog ~args ~env with
  | Ok running ->
    Ok
      { Running_capturing_stdout.running
      ; stdio_dir_path
      ; stdout_file_desc
      ; active = ref true
      }
  | Error e ->
    Unix.close stdout_file_desc;
    File_ops.rm_rf stdio_dir_path;
    Error e
;;

let run_command
      ?(stdin = Unix.stdin)
      ?(stdout = Unix.stdout)
      ?(stderr = Unix.stderr)
      { Command.prog; args; env }
  =
  run ~stdin ~stdout ~stderr prog ~args ~env
;;

let run_command_capturing_stdout
      ?(stdin = Unix.stdin)
      ?(stderr = Unix.stderr)
      { Command.prog; args; env }
  =
  run_capturing_stdout ~stdin ~stderr prog ~args ~env
;;

module Blocking = struct
  let run
        ?(stdin = Unix.stdin)
        ?(stdout = Unix.stdout)
        ?(stderr = Unix.stderr)
        prog
        ~args
        ~env
    =
    let open Result.O in
    run ~stdin ~stdout ~stderr prog ~args ~env >>| Running.wait
  ;;

  let run_capturing_stdout_lines
        ?(stdin = Unix.stdin)
        ?(stderr = Unix.stderr)
        prog
        ~args
        ~env
    =
    let open Result.O in
    run_capturing_stdout ~stdin ~stderr prog ~args ~env
    >>| Running_capturing_stdout.wait_stdout_lines
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

let run_batch_map_stdout_lines commands num_jobs ~f =
  let next_command =
    let remaining_commands_with_indices =
      ref (List.mapi commands ~f:(fun i command -> i, command))
    in
    fun () ->
      match !remaining_commands_with_indices with
      | [] -> None
      | (i, command) :: rest ->
        remaining_commands_with_indices := rest;
        Some (i, command)
  in
  let num_commands = List.length commands in
  let num_jobs =
    match (num_jobs : Num_jobs.t) with
    | Limited limit -> Int.min limit num_commands
    | Unlimited -> num_commands
  in
  let current_jobs =
    Array.init num_jobs ~f:(fun _ ->
      Option.map (next_command ()) ~f:(fun (i, command) ->
        let running =
          run_command_capturing_stdout command |> Error.result_get_or_user_error
        in
        i, running))
  in
  let outputs = Array.make num_commands None in
  let remaining_outputs_to_compute = ref num_commands in
  while !remaining_outputs_to_compute > 0 do
    Unix.sleepf 0.001;
    Array.iteri current_jobs ~f:(fun job_i job ->
      Option.iter job ~f:(fun (out_i, running) ->
        Option.iter
          (Running_capturing_stdout.poll_stdout_lines running)
          ~f:(fun (report, lines) ->
            (* At this point we know the job at index [job_i] is complete, so
               start a new job in its place if possible. *)
            current_jobs.(job_i)
            <- next_command ()
               |> Option.map ~f:(fun (next_out_i, command) ->
                 let running =
                   run_command_capturing_stdout command |> Error.result_get_or_user_error
                 in
                 next_out_i, running);
            Report.error_unless_exit_0 report;
            let value = f lines in
            outputs.(out_i) <- Some value;
            remaining_outputs_to_compute := !remaining_outputs_to_compute - 1)))
  done;
  Array.to_seq outputs |> Seq.map ~f:Option.get |> List.of_seq
;;
