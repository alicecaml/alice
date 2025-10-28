open! Alice_stdlib
open Alice_hierarchy
open Alice_package
module File_ops = Alice_io.File_ops
module Log = Alice_log
include Build_graph.Traverse

module Ctx = struct
  type t =
    { optimization_level : [ `O2 | `O3 ] option
    ; debug : bool
    }

  let debug = { optimization_level = None; debug = true }
  let release = { optimization_level = Some `O2; debug = false }

  let ocamlopt_command t ~args =
    let prog = Alice_which.ocamlopt () in
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

module Ocamldep_cache = struct
  type deps = Path.relative Alice_ocamldep.Deps.t Path.Relative.Map.t

  (* Cache which is serialized in the build directory to avoid running ocamldep
     when it's output is guaranteed to be the same as the previous time it was
     run on some file. *)
  type t =
    { deps : deps
    ; mtime : float
    }

  let filename = Path.relative "ocamldeps_cache.marshal"

  let load ~out_dir ~package =
    let path = out_dir / filename in
    if File_ops.exists path
    then (
      Log.info
        ~package
        [ Pp.textf "Loading ocamldeps cache from: %s" (Alice_ui.path_to_string filename) ];
      let deps =
        File_ops.with_in_channel path ~mode:`Bin ~f:(fun channel ->
          Marshal.from_channel channel)
      in
      let mtime = File_ops.mtime path in
      { deps; mtime })
    else { deps = Path.Relative.Map.empty; mtime = 0.0 }
  ;;

  let store_deps (deps : deps) ~out_dir =
    File_ops.mkdir_p out_dir;
    let path = out_dir / filename in
    File_ops.with_out_channel path ~mode:`Bin ~f:(fun channel ->
      Marshal.to_channel channel deps [])
  ;;

  let get_deps t source_path ~package =
    let source_mtime = File_ops.mtime source_path in
    let run_ocamldep () =
      Log.info
        ~package
        [ Pp.textf
            "Analyzing dependencies of file: %s"
            (Alice_ui.path_to_string source_path)
        ];
      Alice_ocamldep.native_deps source_path
    in
    if source_mtime > t.mtime
    then
      (* Source file is newer than the cache so we need to run ocamldep. *)
      run_ocamldep ()
    else (
      match Path.Relative.Map.find_opt source_path t.deps with
      | None ->
        (* Source file is absent from the cache. This is unusual because the
           source file is older than the cache. Run ocamldep to compute the
           result anyway. *)
        Log.warn
          ~package
          [ Pp.textf
              "The ocamldeps cache (%s) is newer than source file %S, however there is \
               no entry in the ocamldeps cache for that source file."
              (Alice_ui.path_to_string filename)
              (Alice_ui.path_to_string source_path)
          ];
        run_ocamldep ()
      | Some deps -> deps)
  ;;
end

let compile_source_rules ctx dir ~out_dir ~package =
  let ocamldep_cache = Ocamldep_cache.load ~out_dir ~package in
  let deps =
    File_ops.with_working_dir (Dir.path dir) ~f:(fun () ->
      Dir.to_relative dir
      |> Dir.contents
      |> List.sort ~cmp:File.compare_by_path
      |> List.filter_map ~f:(fun file ->
        match
          File.is_regular_or_link file
          && (Path.has_extension file.path ~ext:".ml"
              || Path.has_extension file.path ~ext:".mli")
        with
        | false -> None
        | true ->
          Some (file.path, Ocamldep_cache.get_deps ocamldep_cache file.path ~package)))
    |> Path.Relative.Map.of_list_exn
  in
  Ocamldep_cache.store_deps deps ~out_dir;
  Path.Relative.Map.to_list deps
  |> List.map ~f:(fun (source_path, (deps : Path.relative Alice_ocamldep.Deps.t)) ->
    let inputs = Path.Relative.Set.of_list (source_path :: deps.inputs) in
    let outputs =
      Path.Relative.Set.of_list
        (deps.output
         ::
         (if Path.has_extension source_path ~ext:".ml"
          then [ Path.replace_extension source_path ~ext:".o" ]
          else []))
    in
    Build_rule.static
      { inputs
      ; outputs
      ; commands =
          [ Ctx.ocamlopt_command ctx ~args:[ "-c"; Path.to_filename source_path ] ]
      })
;;

(* Given the path to the source file which will be the module root [root_ml]
   and a list of rules for compiling ocaml source files, computes an order of
   cmx(a) files from the output of given rules such that all dependencies of a
   file preceed that file. *)
let cmx_file_order ~root_ml source_rules_db kind =
  let ext =
    match kind with
    | `Exe -> ".cmx"
    | `Lib -> ".cmx"
  in
  let root_cmx = Path.replace_extension root_ml ~ext in
  let plan =
    Build_rule.Database.create_build_graph source_rules_db ~outputs:[ root_cmx ]
  in
  let rec loop acc traverse =
    let module Traverse = Build_graph.Traverse in
    let cmx_outputs =
      Traverse.outputs traverse
      |> Path.Relative.Set.filter ~f:(Path.has_extension ~ext)
      |> Path.Relative.Set.to_list
    in
    let acc =
      match cmx_outputs with
      | [] -> acc
      | [ cmx_output ] -> cmx_output :: acc
      | _ ->
        Alice_error.panic
          [ Pp.textf "Rule would produce multiple %s files which is not expected" ext ]
    in
    List.fold_left (Traverse.deps traverse) ~init:acc ~f:loop
  in
  loop
    []
    (match Build_graph.traverse plan ~output:root_cmx with
     | None ->
       Alice_error.panic [ Pp.textf "No rule to produce %s" (Path.to_filename root_cmx) ]
     | Some traverse -> traverse)
;;

(* In order to link an executable or library from a collection of .cmx files,
   the ocaml compiler must be passed the cmx files in order such that for each
   file, all of its dependencies preceed it. The [cmx_deps_in_order] argument
   must be a list of paths to .cmx files in such an order. *)
let link_rule ctx ~name ~cmx_deps_in_order kind =
  let o_paths = List.map cmx_deps_in_order ~f:(Path.replace_extension ~ext:".o") in
  let inputs = Path.Relative.Set.of_list (cmx_deps_in_order @ o_paths) in
  let outputs =
    match kind with
    | `Exe -> Path.Relative.Set.singleton name
    | `Lib ->
      (match Path.Relative.extension name with
       | ".cmxa" -> ()
       | other ->
         Alice_error.panic
           [ Pp.textf
               "Unexpected extension for library filename. Expected .cmxa, got %s."
               other
           ]);
      Path.Relative.Set.of_list [ name; Path.Relative.replace_extension name ~ext:".a" ]
  in
  let extra_flags =
    match kind with
    | `Exe -> []
    | `Lib -> [ "-a" ]
  in
  Build_rule.static
    { inputs
    ; outputs
    ; commands =
        [ Ctx.ocamlopt_command
            ctx
            ~args:
              (extra_flags
               @ [ "-o"; Path.Relative.to_filename name ]
               @ List.map cmx_deps_in_order ~f:Path.Relative.to_filename)
        ]
    }
;;

let rules ctx ~name ~root_ml ~source_rules_db kind =
  let cmx_deps_in_order = cmx_file_order ~root_ml source_rules_db kind in
  link_rule ctx ~name ~cmx_deps_in_order kind :: source_rules_db
;;

module Package_build_planner = struct
  type exe_enabled = |
  type exe_disabled = |
  type lib_enabled = |
  type lib_disabled = |

  type (_, _) what =
    | Exe_only : (exe_enabled, lib_disabled) what
    | Lib_only : (exe_disabled, lib_enabled) what
    | Exe_and_lib : (exe_enabled, lib_enabled) what

  type 'what t =
    { build_graph : Build_graph.t
    ; exe_name : Path.Relative.t option
    ; lib_name_cmxa : Path.Relative.t option
    }

  let create
    : type exe lib.
      (exe, lib) what
      -> Ctx.t
      -> Package.t
      -> out_dir:Path.Absolute.t
      -> (exe, lib) what t
    =
    fun what ctx package ~out_dir ->
    let exe_enabled, lib_enabled =
      match what with
      | Exe_only -> true, false
      | Lib_only -> false, true
      | Exe_and_lib -> true, true
    in
    let name = Package.name package |> Package_name.to_string |> Path.relative in
    let exe_root_ml =
      if Package.contains_exe package && exe_enabled
      then Some (Package.exe_root_ml package)
      else None
    in
    let lib_root_ml =
      if Package.contains_lib package && lib_enabled
      then Some (Package.lib_root_ml package)
      else None
    in
    let src_dir = Package.src_dir_exn package in
    let exe_name = if Sys.win32 then Path.add_extension name ~ext:".exe" else name in
    let lib_name_cmxa = Path.add_extension name ~ext:".cmxa" in
    let source_rules_db =
      compile_source_rules ctx src_dir ~out_dir ~package:(Package.id package)
    in
    let lib_rules ~lib_root_ml =
      rules ctx ~name:lib_name_cmxa ~root_ml:lib_root_ml ~source_rules_db `Lib
    in
    let exe_rules ~exe_root_ml =
      rules ctx ~name:exe_name ~root_ml:exe_root_ml ~source_rules_db `Exe
    in
    let outputs, rules =
      match exe_root_ml, lib_root_ml with
      | Some exe_root_ml, Some lib_root_ml ->
        [ exe_name; lib_name_cmxa ], lib_rules ~lib_root_ml @ exe_rules ~exe_root_ml
      | Some exe_root_ml, None -> [ exe_name ], exe_rules ~exe_root_ml
      | None, Some lib_root_ml -> [ lib_name_cmxa ], lib_rules ~lib_root_ml
      | None, None ->
        Alice_error.panic [ Pp.text "Specify one of ~exe_root_ml and ~lib_root_ml" ]
    in
    { build_graph = Build_rule.Database.create_build_graph rules ~outputs
    ; exe_name = Option.map exe_root_ml ~f:(Fun.const exe_name)
    ; lib_name_cmxa = Option.map lib_root_ml ~f:(Fun.const lib_name_cmxa)
    }
  ;;

  let create_exe_only = create Exe_only
  let create_lib_only = create Lib_only
  let create_exe_and_lib = create Exe_and_lib

  let build_exe { build_graph; exe_name; _ } =
    let output =
      match exe_name with
      | None -> Alice_error.panic [ Pp.text "Build plan cannot produce executable." ]
      | Some exe_name -> exe_name
    in
    Build_graph.traverse build_graph ~output |> Option.get
  ;;

  let build_lib { build_graph; lib_name_cmxa; _ } =
    let output =
      match lib_name_cmxa with
      | None -> Alice_error.panic [ Pp.text "Build plan cannot produce library." ]
      | Some lib_name_cmxa -> lib_name_cmxa
    in
    Build_graph.traverse build_graph ~output |> Option.get
  ;;

  let dot { build_graph; _ } = Build_graph.dot build_graph
end
