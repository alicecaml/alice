open! Alice_stdlib
open Alice_hierarchy
open Alice_error

let exe_name () = if Sys.win32 then "ocamldep.opt.exe" else "ocamldep.opt"
let command args = Command.create (exe_name ()) ~args

let run_lines args =
  match Alice_io.Process.Blocking.run_command_capturing_stdout_lines (command args) with
  | Ok (status, output) ->
    Alice_io.Process.Status.panic_unless_exit_0 status;
    output
  | Error `Prog_not_available -> panic [ Pp.textf "Program %S not found!" (exe_name ()) ]
;;

module Deps = struct
  type 'a t =
    { output : 'a Path.t
    ; inputs : 'a Path.t list
    }

  let to_dyn { output; inputs } =
    Dyn.record [ "output", Path.to_dyn output; "inputs", Dyn.list Path.to_dyn inputs ]
  ;;

  let of_line path_kind line =
    match String.lsplit2 line ~on:':' with
    | None ->
      panic
        [ Pp.textf "Expected line of the form \"<output> : <inputs>\", but got %S" line ]
    | Some (left, right) ->
      let left = String.trim left in
      let right = String.trim right in
      let output = Path.of_filename_checked path_kind left in
      let inputs =
        if String.is_empty right
        then []
        else
          String.split_on_char right ~sep:' '
          |> List.map ~f:(Path.of_filename_checked path_kind)
      in
      { output; inputs }
  ;;
end

let native_deps path =
  if not (Alice_io.File_ops.exists path)
  then panic [ Pp.textf "File does not exist: %s" (Path.to_filename path) ];
  match run_lines [ "-one-line"; "-native"; Path.to_filename path ] with
  | [ line ] -> Deps.of_line (Path.kind path) line
  | [] -> panic [ Pp.text "Unexpected empty output!" ]
  | _ -> panic [ Pp.text "Unexpected multiple lines of output!" ]
;;
