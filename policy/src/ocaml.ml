open! Alice_stdlib
open Common
open Alice_hierarchy
module Rule = Alice_engine.Rule
module Build = Alice_engine.Build_plan.Build

module Ctx = struct
  type t =
    { optimization_level : [ `O2 | `O3 ] option
    ; debug : bool
    }

  let ocamlopt_command t ~args =
    let prog = "ocamlopt.opt" in
    let args =
      (if t.debug then [ "-g" ] else [])
      @ (match t.optimization_level with
         | None -> []
         | Some `O2 -> [ "-O2" ]
         | Some `O3 -> [ "-O3" ])
      @ args
    in
    Command.create prog ~args
  ;;
end

let all_ml_files = all_files_with_extension ~ext:".ml"
let all_mli_files = all_files_with_extension ~ext:".mli"

let compile_source_rule ctx dir =
  let all_mli_files_set = Path.Relative.Set.of_list (all_mli_files dir) in
  Rule.create ~f:(fun target ->
    let commands source_file =
      [ Ctx.ocamlopt_command ctx ~args:[ "-c"; Path.to_filename source_file ] ]
    in
    let has_interface =
      Path.Relative.Set.mem (Path.replace_extension target ~ext:".mli") all_mli_files_set
    in
    let build_without_interface () =
      (* When no interface file is present, generate all output files with a single command. *)
      { Build.inputs =
          Path.Relative.Set.singleton (Path.replace_extension target ~ext:".ml")
      ; outputs =
          Path.Relative.Set.of_list
            [ Path.replace_extension target ~ext:".cmi"
            ; Path.replace_extension target ~ext:".cmx"
            ; Path.replace_extension target ~ext:".o"
            ]
      ; commands = commands (Path.replace_extension target ~ext:".ml")
      }
    in
    match Path.extension target with
    | ".cmi" ->
      let build =
        if has_interface
        then
          (* If the interface is present then generate the .cmi file from the .mli file. *)
          { Build.inputs =
              Path.Relative.Set.singleton (Path.replace_extension target ~ext:".mli")
          ; outputs = Path.Relative.Set.singleton target
          ; commands = commands (Path.replace_extension target ~ext:".mli")
          }
        else build_without_interface ()
      in
      Some build
    | ".o" | ".cmx" ->
      let build =
        if has_interface
        then
          (* If the interface is present then the .cmi file must be generated
             before the object files, and compiling the .ml file won't produce
             an interface file. *)
          { Build.inputs =
              Path.Relative.Set.of_list
                [ Path.replace_extension target ~ext:".ml"
                ; Path.replace_extension target ~ext:".cmi"
                ]
          ; outputs =
              Path.Relative.Set.of_list
                [ Path.replace_extension target ~ext:".cmx"
                ; Path.replace_extension target ~ext:".o"
                ]
          ; commands = commands (Path.replace_extension target ~ext:".ml")
          }
        else build_without_interface ()
      in
      Some build
    | _ -> None)
;;
