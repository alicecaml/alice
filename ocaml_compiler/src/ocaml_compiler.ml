open! Alice_stdlib
open Alice_error
open Alice_hierarchy

type t =
  { filename : Filename.t
  ; env : Env.t
  }

let create filename env = { filename; env }
let filename { filename; _ } = filename
let env { env; _ } = env
let command { filename; env } ~args = Command.create filename ~args env

module Depend = struct
  let command ocaml_compiler args = command ocaml_compiler ~args:("-depend" :: args)

  let run_lines ocaml_compiler proc_mgr args =
    let command = command ocaml_compiler args in
    Alice_io.Process.Eio.run_command_capturing_stdout_lines proc_mgr command
    |> Alice_io.Process.Eio.result_ok_or_exn
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
            [ Pp.textf
                "Expected line of the form \"<output> : <inputs>\", but got %S"
                line
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

  let native_deps ocaml_compiler proc_mgr path =
    if not (Alice_io.File_ops.exists path)
    then
      panic [ Pp.textf "File does not exist: %s" (Alice_ui.absolute_path_to_string path) ];
    match
      run_lines
        ocaml_compiler
        proc_mgr
        [ "-one-line"
        ; "-native"
        ; "-I"
        ; Absolute_path.parent path |> Absolute_path.Root_or_non_root.to_filename
        ; Absolute_path.to_filename path
        ]
    with
    | [ line ] | [ line; "" ] -> Deps.of_line line
    | [] -> panic [ Pp.text "Unexpected empty output!" ]
    | lines ->
      panic
        [ Pp.text "Unexpected multiple lines of output:"
        ; Pp.concat_map lines ~f:(Pp.textf "%S") ~sep:(Pp.text ", ")
        ]
  ;;
end

module Deps = Depend.Deps

let depends_native = Depend.native_deps

module Config = struct
  let command ocaml_compiler = command ocaml_compiler ~args:[ "-config" ]

  let run_lines ocaml_compiler proc_mgr =
    let command = command ocaml_compiler in
    Alice_io.Process.Eio.run_command_capturing_stdout_lines proc_mgr command
    |> Alice_io.Process.Eio.result_ok_or_exn
  ;;

  let standard_library ocaml_compiler proc_mgr =
    let lines = run_lines ocaml_compiler proc_mgr in
    let path_opt =
      List.find_map lines ~f:(fun line ->
        match String.lsplit2 line ~on:' ' with
        | None -> None
        | Some (left, right) ->
          if String.equal left "standard_library:"
          then Some (String.trim right |> Absolute_path.of_filename_assert_non_root)
          else None)
    in
    match path_opt with
    | Some path -> path
    | None ->
      user_exn
        [ Pp.textf
            "No \"stardard_library\" field in output of `%s -config`."
            ocaml_compiler.filename
        ]
  ;;
end

let standard_library = Config.standard_library
