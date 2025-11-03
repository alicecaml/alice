open! Alice_stdlib
open Alice_hierarchy

let tar ~tarball_file ~output_dir =
  let args =
    [ "-x"
    ; "-C"
    ; Absolute_path.to_filename output_dir
    ; "-f"
    ; Absolute_path.to_filename tarball_file
    ]
  in
  Command.create "tar" ~args
;;

let extract ~tarball_file ~output_dir ~env =
  match tar ~tarball_file ~output_dir |> Process.Blocking.run_command ~env with
  | Ok (Process.Status.Exited 0) -> ()
  | _ ->
    Alice_error.panic
      [ Pp.textf "Unable to extract tarball: %s" (Absolute_path.to_filename tarball_file)
      ]
;;
