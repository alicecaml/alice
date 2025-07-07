open! Alice_stdlib
open Alice_hierarchy

let tar ~tarball_file ~output_dir =
  let args =
    [ "-x"; "-C"; Path.to_filename output_dir; "-f"; Path.to_filename tarball_file ]
  in
  Command.create "tar" ~args
;;

let extract ~tarball_file ~output_dir =
  match tar ~tarball_file ~output_dir |> Process.Blocking.run_command with
  | Ok (Process.Status.Exited 0) -> ()
  | _ ->
    Alice_error.panic
      [ Pp.textf "Unable to extract tarball: %s" (Path.to_filename tarball_file) ]
;;
