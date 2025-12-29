open! Alice_stdlib
open Alice_hierarchy
module Log = Alice_log

let curl env ~url ~output_file =
  let args =
    [ "-L" (* --location: Handle the case when a page has moved. *)
    ; "-S" (* --show-error: Show an error when the download fails. *)
    ; "-#" (* --progress-bar: Show a progress bar *)
    ; "-o" (* --output: Store the result in a file *)
    ; Absolute_path.to_filename output_file
    ; "--"
    ; url
    ]
  in
  Command.create "curl" ~args env
;;

let wget env ~url ~output_file =
  let args = [ "-O"; Absolute_path.to_filename output_file; url ] in
  Command.create "wget" ~args env
;;

let fetch env ~url ~output_file =
  Log.info [ Pp.textf "Downloading %s to %s" url (Absolute_path.to_filename output_file) ];
  match curl env ~url ~output_file |> Process.Blocking.run_command with
  | Ok { status = Process.Status.Exited 0; _ } ->
    assert (Sys.file_exists (Absolute_path.to_filename output_file));
    ()
  | _ ->
    (match wget env ~url ~output_file |> Process.Blocking.run_command with
     | Ok { status = Process.Status.Exited 0; _ } ->
       assert (Sys.file_exists (Absolute_path.to_filename output_file));
       ()
     | _ -> Alice_error.panic [ Pp.textf "Unable to download: %s" url ])
;;
