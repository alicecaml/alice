open! Alice_stdlib
open Alice_hierarchy

let tar env ~tarball_file ~output_dir =
  let args =
    [ "-x"
    ; "-C"
    ; Absolute_path.to_filename output_dir
    ; "-f"
    ; Absolute_path.to_filename tarball_file
    ]
  in
  Command.create "tar" ~args env
;;

let extract env ~tarball_file ~output_dir =
  match tar env ~tarball_file ~output_dir |> Process.Blocking.run_command with
  | Ok (Process.Status.Exited 0) -> ()
  | _ ->
    Alice_error.panic
      [ Pp.textf "Unable to extract tarball: %s" (Absolute_path.to_filename tarball_file)
      ]
;;
