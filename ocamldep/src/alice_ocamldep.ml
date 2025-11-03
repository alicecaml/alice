open! Alice_stdlib
open Alice_hierarchy
open Alice_error

let ocamlopt_exe () = Alice_which.ocamlopt ()
let command args = Command.create (ocamlopt_exe ()) ~args:("-depend" :: args)

let run_lines args =
  let command = command args in
  match Alice_io.Process.Blocking.run_command_capturing_stdout_lines command with
  | Ok (status, output) ->
    Alice_io.Process.Status.panic_unless_exit_0 status;
    output
  | Error `Prog_not_available ->
    user_exn
      [ Pp.textf
          "Program %S not found while trynig to run command: %s"
          (ocamlopt_exe ())
          (Command.to_string command)
      ]
;;

module Deps = struct
  type t =
    { output : Basename.t
    ; inputs : Basename.t list
    }

  let to_dyn { output; inputs } =
    Dyn.record
      [ "output", Basename.to_dyn output; "inputs", Dyn.list Basename.to_dyn inputs ]
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
    let output =
      Absolute_path.of_filename_assert_non_root left |> Absolute_path.basename
    in
    let inputs =
      if String.is_empty right
      then []
      else
        String.split_on_char right ~sep:' '
        |> List.map ~f:(fun filename ->
          Absolute_path.of_filename_assert_non_root filename |> Absolute_path.basename)
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
      ; Absolute_path.parent path |> Absolute_path.Root_or_non_root.to_filename
      ; Absolute_path.to_filename path
      ]
  with
  | [ line ] -> Deps.of_line line
  | [] -> panic [ Pp.text "Unexpected empty output!" ]
  | _ -> panic [ Pp.text "Unexpected multiple lines of output!" ]
;;
