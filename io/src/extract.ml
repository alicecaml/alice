open! Alice_stdlib

let tar ~tarball_file ~output_dir =
  let args = [ "-x"; "-C"; output_dir; "-f"; tarball_file ] in
  Command.create "tar" ~args
;;

let extract ~tarball_file ~output_dir =
  match tar ~tarball_file ~output_dir |> Process.Blocking.run_command with
  | Ok (Process.Status.Exited 0) -> ()
  | _ -> Alice_error.panic [ Pp.textf "Unable to extract tarball: %s" tarball_file ]
;;
