open! Alice_stdlib
open Alice_hierarchy
module Rule = Alice_engine.Rule
module Build_plan = Alice_engine.Build_plan
module Build = Alice_engine.Build_plan.Build

module Ctx = struct
  type t =
    { optimization_level : [ `O2 | `O3 ] option
    ; debug : bool
    }

  let debug = { optimization_level = None; debug = true }
  let release = { optimization_level = Some `O2; debug = false }

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

let compile_source_rules ctx dir =
  Alice_io.File_ops.with_working_dir (Dir.path dir) ~f:(fun () ->
    Dir.to_relative dir
    |> Dir.contents
    |> List.filter_map ~f:(fun file ->
      if
        File.is_regular_or_link file
        && (Path.has_extension file.path ~ext:".ml"
            || Path.has_extension file.path ~ext:".mli")
      then (
        let deps = Alice_ocamldep.native_deps file.path in
        let inputs = Path.Relative.Set.of_list (file.path :: deps.inputs) in
        let outputs =
          Path.Relative.Set.of_list
            (deps.output
             ::
             (if Path.has_extension file.path ~ext:".ml"
              then [ Path.replace_extension file.path ~ext:".o" ]
              else []))
        in
        let rule =
          Rule.static
            { inputs
            ; outputs
            ; commands =
                [ Ctx.ocamlopt_command ctx ~args:[ "-c"; Path.to_filename file.path ] ]
            }
        in
        Some rule)
      else None))
;;

(* Given the path to the source file which will be the module root [root_ml]
   and a list of rules for compiling ocaml source files, computes an order of
   cmx files from the output of given rules such that all dependencies of a
   file preceed that file. *)
let cmx_file_order ~root_ml source_rules_db =
  let root_cmx = Path.replace_extension root_ml ~ext:".cmx" in
  let plan = Rule.Database.create_build_plan source_rules_db ~output:root_cmx in
  let rec loop acc traverse =
    let module Traverse = Build_plan.Traverse in
    let cmx_outputs =
      Traverse.outputs traverse
      |> Path.Relative.Set.filter ~f:(Path.has_extension ~ext:".cmx")
      |> Path.Relative.Set.to_list
    in
    let acc =
      match cmx_outputs with
      | [] -> acc
      | [ cmx_output ] -> cmx_output :: acc
      | _ ->
        Alice_error.panic
          [ Pp.text "Rule would produce multiple cmx files which is not expected" ]
    in
    List.fold_left (Traverse.deps traverse) ~init:acc ~f:loop
  in
  loop
    []
    (match Build_plan.traverse plan ~output:root_cmx with
     | None ->
       Alice_error.panic [ Pp.textf "No rule to produce %s" (Path.to_filename root_cmx) ]
     | Some traverse -> traverse)
;;

(* In order to link an executable from a collection of .cmx files, the ocaml
   compiler must be passed the cmx files in order such that for each file, all
   of its dependencies preceed it. The [cmx_deps_in_order] argument must be a
   list of paths to .cmx files in such an order. *)
let link_exe_rule ctx ~exe_name ~cmx_deps_in_order =
  let o_paths = List.map cmx_deps_in_order ~f:(Path.replace_extension ~ext:".o") in
  let inputs = Path.Relative.Set.of_list (cmx_deps_in_order @ o_paths) in
  Rule.static
    { inputs
    ; outputs = Path.Relative.Set.singleton exe_name
    ; commands =
        [ Ctx.ocamlopt_command
            ctx
            ~args:
              ([ "-o"; Path.Relative.to_filename exe_name ]
               @ List.map cmx_deps_in_order ~f:Path.Relative.to_filename)
        ]
    }
;;

let exe_rules ctx ~exe_name ~root_ml ~src_dir =
  let source_rules_db = compile_source_rules ctx src_dir in
  let cmx_deps_in_order = cmx_file_order ~root_ml source_rules_db in
  link_exe_rule ctx ~exe_name ~cmx_deps_in_order :: source_rules_db
;;

let build_exe ctx ~exe_name ~root_ml ~src_dir =
  exe_rules ctx ~exe_name ~root_ml ~src_dir
  |> Rule.Database.create_build_plan ~output:exe_name
  |> Build_plan.traverse ~output:exe_name
  |> Option.get
;;
