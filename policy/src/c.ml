open! Alice_stdlib
open Alice_hierarchy
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

let all_files_with_extension (dir : _ Dir.t) ~ext =
  List.filter_map dir.contents ~f:(fun (file : _ File.t) ->
    if
      File.is_regular_or_link file
      && Filename.has_extension (Path.to_filename file.path) ~ext
    then Some (Path.to_filename file.path)
    else None)
;;

let all_header_files = all_files_with_extension ~ext:".h"
let all_source_files = all_files_with_extension ~ext:".c"

let all_object_files dir =
  all_source_files dir |> List.map ~f:(Filename.replace_extension ~ext:".o")
;;

let c_to_o_rule ctx dir =
  let all_header_files = all_header_files dir in
  Rule.create ~f:(fun target ->
    match Filename.extension target with
    | ".o" ->
      let with_c_extension = Filename.replace_extension target ~ext:".c" in
      let inputs =
        (* Each object file depends on all header files because it's possible
           that any .c file could #include any .h file. *)
        with_c_extension :: all_header_files
      in
      Some
        { Build.inputs = Filename.Set.of_list inputs
        ; commands = [ Ctx.cc_command ctx ~args:[ "-c"; with_c_extension; "-o"; target ] ]
        }
    | _ -> None)
;;

let link_exe_rule ~exe_name ctx dir =
  let all_object_files = all_object_files dir in
  Rule.create_fixed_output
    ~output:exe_name
    ~build:
      { Build.inputs = Filename.Set.of_list all_object_files
      ; commands = [ Ctx.cc_command ctx ~args:(all_object_files @ [ "-o"; exe_name ]) ]
      }
;;

let exe_rules ~exe_name ctx dir = [ c_to_o_rule ctx dir; link_exe_rule ~exe_name ctx dir ]
