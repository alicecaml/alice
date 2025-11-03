open! Alice_stdlib
open Alice_hierarchy
module Log = Alice_log

let curl ~url ~output_file =
  let args =
    [ "-L" (* --location: Handle the case when a page has moved. *)
    ; "-s" (* --show-error: Show an error when the download fails. *)
    ; "-o" (* --output: Store the result in a file *)
    ; Absolute_path.to_filename output_file
    ; "--"
    ; url
    ]
  in
  Command.create "curl" ~args
;;

let wget ~url ~output_file =
  let args = [ "-O"; Absolute_path.to_filename output_file; url ] in
  Command.create "wget" ~args
;;

let fetch env ~url ~output_file =
  Log.info [ Pp.textf "Downloading %s to %s" url (Absolute_path.to_filename output_file) ];
  match curl ~url ~output_file |> Process.Blocking.run_command ~env with
  | Ok (Process.Status.Exited 0) ->
    assert (Sys.file_exists (Absolute_path.to_filename output_file));
    ()
  | _ ->
    (match wget ~url ~output_file |> Process.Blocking.run_command ~env with
     | Ok (Process.Status.Exited 0) ->
       assert (Sys.file_exists (Absolute_path.to_filename output_file));
       ()
     | _ -> Alice_error.panic [ Pp.textf "Unable to download: %s" url ])
;;
