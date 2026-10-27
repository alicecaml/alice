open! Alice_stdlib
open Alice_error
open Alice_hierarchy
module Builtin_module = Alice_builtin_module

type t =
  { ocamlopt : Filename.t
  ; ocamlc : Filename.t
  ; ocaml : Filename.t
  ; env : Env.t
  }

let create ~ocamlopt ~ocamlc ~ocaml env = { ocamlopt; ocamlc; ocaml; env }
let ocamlopt { ocamlopt; _ } = ocamlopt
let ocamlc { ocamlc; _ } = ocamlc
let ocaml { ocaml; _ } = ocaml
let ocamlopt_command { ocamlopt; env; _ } ~args = Command.create ocamlopt ~args env
let ocamlc_command { ocamlc; env; _ } ~args = Command.create ocamlc ~args env
let ocaml_command { ocaml; env; _ } ~args = Command.create ocaml ~args env
let env { env; _ } = env

module Config = struct
  let command ocaml_toolchain = ocamlopt_command ocaml_toolchain ~args:[ "-config" ]

  let run_lines ocaml_toolchain =
    let command = command ocaml_toolchain in
    match Alice_io.Process.Blocking.run_command_capturing_stdout_lines command with
    | Ok (report, output) ->
      Alice_io.Process.Report.error_unless_exit_0 report;
      output
    | Error (`Prog_not_available prog) ->
      user_exn
        [ Pp.textf
            "Program %S not found while trying to run command: %s"
            prog
            (Command.to_string_ignore_env command)
        ]
  ;;

  let standard_library ocaml_toolchain =
    let lines = run_lines ocaml_toolchain in
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
            ocaml_toolchain.ocamlopt
        ]
  ;;
end

module Depend = struct
  let command ocaml_toolchain args =
    ocamlopt_command ocaml_toolchain ~args:("-depend" :: args)
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

    let of_line ~local_src_dir_path line =
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
      let output_absolute = Absolute_path.of_filename_assert_non_root left in
      let output = Absolute_path.basename output_absolute in
      let inputs =
        if String.is_empty right
        then []
        else
          String.split_on_char right ~sep:' '
          |> List.map ~f:(fun filename ->
            let input_path = Absolute_path.of_filename_assert_non_root filename in
            match Absolute_path.chop_prefix_opt input_path ~prefix:local_src_dir_path with
            | Some local_src_file ->
              (match Relative_path.to_basename_opt local_src_file with
               | Some basename -> basename
               | None ->
                 Alice_error.panic
                   [ Pp.textf
                       "Expected all dependencies under local src dir to be at a depth \
                        of 1 but encountered dependency %S while enumerating \
                        dependencies of %S."
                       (Absolute_path.to_filename input_path)
                       (Absolute_path.to_filename output_absolute)
                   ])
            | None ->
              Alice_error.panic
                [ Pp.textf
                    "Expected all dependencies to be under local src dir but encountered \
                     dependency %S while enumerating dependencies of %S."
                    (Absolute_path.to_filename input_path)
                    (Absolute_path.to_filename output_absolute)
                ])
      in
      { output; inputs }
    ;;

    let command ocaml_toolchain compiler_backend path =
      let backend_arg =
        match (compiler_backend : Compiler_backend.t) with
        | Native -> "-native"
        | Bytecode -> "-bytecode"
      in
      command
        ocaml_toolchain
        [ backend_arg
        ; "-one-line"
        ; "-I"
        ; Absolute_path.parent path |> Absolute_path.Root_or_non_root.to_filename
        ; Absolute_path.to_filename path
        ]
    ;;

    let parse_stdout_lines ~local_src_dir_path = function
      | [ line ] | [ line; "" ] -> of_line ~local_src_dir_path line
      | [] -> panic [ Pp.text "Unexpected empty output!" ]
      | lines ->
        panic
          [ Pp.text "Unexpected multiple lines of output:"
          ; Pp.concat_map lines ~f:(Pp.textf "%S") ~sep:(Pp.text ", ")
          ]
    ;;

    let run_batch
          ocaml_toolchain
          compiler_backend
          num_jobs
          ~local_src_dir_path
          ~src_file_names
      =
      let commands =
        List.map src_file_names ~f:(fun src_file_name ->
          Absolute_path.concat_basename local_src_dir_path src_file_name
          |> command ocaml_toolchain compiler_backend)
      in
      Alice_io.Process.run_batch_map_stdout_lines
        commands
        num_jobs
        ~f:(parse_stdout_lines ~local_src_dir_path)
    ;;
  end
end

module Deps = Depend.Deps

let depends_batch = Depend.Deps.run_batch
let standard_library = Config.standard_library

let builtin_module_dir t builtin_module =
  standard_library t / Basename.of_filename (Builtin_module.to_string builtin_module)
;;

let builtin_module_cmxa t builtin_module =
  builtin_module_dir t builtin_module
  / Basename.of_filename (sprintf "%s.cmxa" (Builtin_module.to_string builtin_module))
;;

let builtin_module_cma t builtin_module =
  builtin_module_dir t builtin_module
  / Basename.of_filename (sprintf "%s.cma" (Builtin_module.to_string builtin_module))
;;
