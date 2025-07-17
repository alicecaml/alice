open! Alice_stdlib
open Alice_error

let exe_name = "ocamldep.opt"
let command args = Command.create exe_name ~args

let run_lines args =
  match Alice_io.Process.Blocking.run_command_capturing_stdout_lines (command args) with
  | Ok (status, output) ->
    Alice_io.Process.Status.panic_unless_exit_0 status;
    output
  | Error `Prog_not_available -> panic [ Pp.textf "Program %S not found!" exe_name ]
;;

module Deps = struct
  type t =
    { output : Filename.t
    ; inputs : Filename.t list
    }

  let to_dyn { output; inputs } =
    Dyn.record
      [ "output", Filename.to_dyn output; "inputs", Dyn.list Filename.to_dyn inputs ]
  ;;

  let of_line line =
    match String.lsplit2 line ~on:':' with
    | None ->
      panic
        [ Pp.textf "Expected line of the form \"<output> : <inputs>\", but got %S" line ]
    | Some (left, right) ->
      let left = String.trim left in
      let right = String.trim right in
      let output = left in
      let inputs = String.split_on_char right ~sep:' ' in
      { output; inputs }
  ;;
end

let native_deps filename =
  match run_lines [ "-one-line"; "-native"; filename ] with
  | [ line ] -> Deps.of_line line
  | [] -> panic [ Pp.text "Unexpected empty output!" ]
  | _ -> panic [ Pp.text "Unexpected multiple lines of output!" ]
;;
