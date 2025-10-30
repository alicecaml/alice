open! Alice_stdlib
open Alice_hierarchy
open Alice_error

let exe_name () = Alice_which.ocamldep ()
let command args = Command.create (exe_name ()) ~args

let run_lines args =
  match Alice_io.Process.Blocking.run_command_capturing_stdout_lines (command args) with
  | Ok (status, output) ->
    Alice_io.Process.Status.panic_unless_exit_0 status;
    output
  | Error `Prog_not_available -> panic [ Pp.textf "Program %S not found!" (exe_name ()) ]
;;

module Deps = struct
  type t =
    { output : Path.Relative.t
    ; inputs : Path.Relative.t list
    }

  let to_dyn { output; inputs } =
    Dyn.record [ "output", Path.to_dyn output; "inputs", Dyn.list Path.to_dyn inputs ]
  ;;

  let separator_pattern = lazy (Re.str " : " |> Re.compile)

  let of_line line =
    let parts = Re.split_delim (Lazy.force separator_pattern) line in
    let left, right =
      match parts with
      | [] | _ :: _ :: _ :: _ ->
        panic
          [ Pp.textf "Expected line of the form \"<output> : <inputs>\", but got %S" line
          ]
      | [ left ] -> String.trim left, ""
      | [ left; right ] ->
        let left = String.trim left in
        let right = String.trim right in
        left, right
    in
    let output = Path.absolute left |> Path.basename in
    let inputs =
      if String.is_empty right
      then []
      else
        String.split_on_char right ~sep:' '
        |> List.map ~f:(fun filename -> Path.absolute filename |> Path.basename)
    in
    { output; inputs }
  ;;
end

let native_deps path =
  if not (Alice_io.File_ops.exists path)
  then panic [ Pp.textf "File does not exist: %s" (Alice_ui.path_to_string path) ];
  match
    run_lines
      [ "-one-line"
      ; "-native"
      ; "-I"
      ; Path.dirname path |> Path.to_filename
      ; Path.to_filename path
      ]
  with
  | [ line ] -> Deps.of_line line
  | [] -> panic [ Pp.text "Unexpected empty output!" ]
  | _ -> panic [ Pp.text "Unexpected multiple lines of output!" ]
;;
