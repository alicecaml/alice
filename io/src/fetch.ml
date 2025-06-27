open! Alice_stdlib

let curl ~url ~output_file =
  let args =
    [ "-L" (* --location: Handle the case when a page has moved. *)
    ; "-s" (* --show-error: Show an error when the download fails. *)
    ; "-o" (* --output: Store the result in a file *)
    ; output_file
    ; "--"
    ; url
    ]
  in
  Command.create "curl" ~args
;;

let wget ~url ~output_file =
  let args = [ "-O"; output_file; url ] in
  Command.create "wget" ~args
;;

let fetch ~url ~output_file =
  match curl ~url ~output_file |> Process.Blocking.run_command with
  | Ok (Process.Status.Exited 0) ->
    assert (Sys.file_exists output_file);
    ()
  | _ ->
    (match wget ~url ~output_file |> Process.Blocking.run_command with
     | Ok (Process.Status.Exited 0) ->
       assert (Sys.file_exists output_file);
       ()
     | _ -> Alice_error.panic [ Pp.textf "Unable to download: %s" url ])
;;
