open! Alice_stdlib
open Alice_hierarchy
open Common
module Rule = Alice_engine.Rule
module Build = Alice_engine.Build_plan.Build

module Ctx = struct
  type t =
    { optimization_level : [ `O0 | `O1 | `O2 | `O3 ] option
    ; debug : bool
    ; override_c_compiler : string option
    }

  let cc_command t ~args =
    let prog = Option.value t.override_c_compiler ~default:"cc" in
    let args =
      (if t.debug then [ "-g" ] else [])
      @ (match t.optimization_level with
         | None -> []
         | Some `O0 -> [ "-O0" ]
         | Some `O1 -> [ "-O1" ]
         | Some `O2 -> [ "-O2" ]
         | Some `O3 -> [ "-O3" ])
      @ args
    in
    Command.create prog ~args
  ;;

  let debug = { optimization_level = Some `O0; debug = true; override_c_compiler = None }

  let release =
    { optimization_level = Some `O2; debug = false; override_c_compiler = None }
  ;;
end

let all_header_files = all_files_with_extension ~ext:".h"
let all_source_files = all_files_with_extension ~ext:".c"

let all_object_files dir =
  all_source_files dir |> List.map ~f:(Path.replace_extension ~ext:".o")
;;

let c_to_o_rule ctx dir =
  let all_header_files = all_header_files dir in
  Rule.create ~f:(fun target ->
    match Path.extension target with
    | ".o" ->
      let with_c_extension = Path.replace_extension target ~ext:".c" in
      let inputs =
        (* Each object file depends on all header files because it's possible
           that any .c file could #include any .h file. *)
        with_c_extension :: all_header_files
      in
      Some
        { Build.inputs = Path.Relative.Set.of_list inputs
        ; outputs = Path.Relative.Set.singleton target
        ; commands =
            [ Ctx.cc_command
                ctx
                ~args:
                  [ "-c"
                  ; Path.to_filename with_c_extension
                  ; "-o"
                  ; Path.to_filename target
                  ]
            ]
        }
    | _ -> None)
;;

let link_exe_rule ~exe_name ctx dir =
  let all_object_files = all_object_files dir in
  Rule.create_fixed_output
    ~output:exe_name
    ~build:
      { Build.inputs = Path.Relative.Set.of_list all_object_files
      ; outputs = Path.Relative.Set.singleton exe_name
      ; commands =
          [ Ctx.cc_command
              ctx
              ~args:
                (List.map all_object_files ~f:Path.Relative.to_filename
                 @ [ "-o"; Path.Relative.to_filename exe_name ])
          ]
      }
;;

let exe_rules ~exe_name ctx dir = [ c_to_o_rule ctx dir; link_exe_rule ~exe_name ctx dir ]
