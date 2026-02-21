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

  module Native_deps = struct
    let command ocaml_compiler path =
      command
        ocaml_compiler
        [ "-one-line"
        ; "-native"
        ; "-I"
        ; Absolute_path.parent path |> Absolute_path.Root_or_non_root.to_filename
        ; Absolute_path.to_filename path
        ]
    ;;

    let parse_stdout_lines = function
      | [ line ] | [ line; "" ] -> Deps.of_line line
      | [] -> panic [ Pp.text "Unexpected empty output!" ]
      | lines ->
        panic
          [ Pp.text "Unexpected multiple lines of output:"
          ; Pp.concat_map lines ~f:(Pp.textf "%S") ~sep:(Pp.text ", ")
          ]
    ;;

    let run_batch ocaml_compiler num_jobs paths =
      let commands = List.map paths ~f:(command ocaml_compiler) in
      Alice_io.Process.run_batch_map_stdout_lines commands num_jobs ~f:parse_stdout_lines
    ;;
  end
end

module Deps = Depend.Deps

let depends_native_batch = Depend.Native_deps.run_batch

module Config = struct
  let command ocaml_compiler = command ocaml_compiler ~args:[ "-config" ]

  let run_lines ocaml_compiler io_ctx =
    let command = command ocaml_compiler in
    Alice_io.Process.Eio.run_command_capturing_stdout_lines io_ctx command
    |> Alice_io.Process.Eio.result_ok_or_exn
  ;;

  let standard_library ocaml_compiler io_ctx =
    let lines = run_lines ocaml_compiler io_ctx in
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
