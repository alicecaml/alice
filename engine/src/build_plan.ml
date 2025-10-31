open! Alice_stdlib
open Type_bool
open Alice_hierarchy
open Alice_package
module File_ops = Alice_io.File_ops
module Log = Alice_log
include Build_graph.Traverse

module Ocamldep_cache_ = struct
  type deps = Alice_ocamldep.Deps.t Path.Absolute.Map.t

  (* Cache which is serialized in the build directory to avoid running ocamldep
     when it's output is guaranteed to be the same as the previous time it was
     run on some file. *)
  type t =
    { deps : deps
    ; mtime : float
    }

  let load build_dir package_id =
    let path = Build_dir.package_ocamldeps_cache_file build_dir package_id in
    if File_ops.exists path
    then (
      Log.info
        ~package_id
        [ Pp.textf "Loading ocamldeps cache from: %s" (Alice_ui.path_to_string path) ];
      let deps =
        File_ops.with_in_channel path ~mode:`Bin ~f:(fun channel ->
          Marshal.from_channel channel)
      in
      let mtime = File_ops.mtime path in
      { deps; mtime })
    else { deps = Path.Absolute.Map.empty; mtime = 0.0 }
  ;;

  let store_deps (deps : deps) build_dir package_id =
    let path = Build_dir.package_ocamldeps_cache_file build_dir package_id in
    File_ops.mkdir_p (Path.dirname path);
    File_ops.with_out_channel path ~mode:`Bin ~f:(fun channel ->
      Marshal.to_channel channel deps [])
  ;;

  let get_deps t ~source_path build_dir package_id =
    let path = Build_dir.package_ocamldeps_cache_file build_dir package_id in
    let source_mtime = File_ops.mtime source_path in
    let run_ocamldep () =
      Log.info
        ~package_id
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
      match Path.Absolute.Map.find_opt source_path t.deps with
      | None ->
        (* Source file is absent from the cache. This is unusual because the
           source file is older than the cache. Run ocamldep to compute the
           result anyway. *)
        Log.warn
          ~package_id
          [ Pp.textf
              "The ocamldeps cache (%s) is newer than source file %S, however there is \
               no entry in the ocamldeps cache for that source file."
              (Alice_ui.path_to_string path)
              (Alice_ui.path_to_string source_path)
          ];
        run_ocamldep ()
      | Some deps -> deps)
  ;;
end

module Ocamldep_cache = struct
  type deps = Alice_ocamldep.Deps.t Path.Absolute.Map.t

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
        ~package_id:package
        [ Pp.textf "Loading ocamldeps cache from: %s" (Alice_ui.path_to_string filename) ];
      let deps =
        File_ops.with_in_channel path ~mode:`Bin ~f:(fun channel ->
          Marshal.from_channel channel)
      in
      let mtime = File_ops.mtime path in
      { deps; mtime })
    else { deps = Path.Absolute.Map.empty; mtime = 0.0 }
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
        ~package_id:package
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
      match Path.Absolute.Map.find_opt source_path t.deps with
      | None ->
        (* Source file is absent from the cache. This is unusual because the
           source file is older than the cache. Run ocamldep to compute the
           result anyway. *)
        Log.warn
          ~package_id:package
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

let compilation_ops dir build_dir package_id =
  let ocamldep_cache = Ocamldep_cache_.load build_dir package_id in
  let deps =
    Dir.contents dir
    |> List.filter ~f:(fun file ->
      File.is_regular_or_link file
      && (Path.has_extension file.path ~ext:".ml"
          || Path.has_extension file.path ~ext:".mli"))
    |> List.sort ~cmp:File.compare_by_path
    |> List.map ~f:(fun (file : _ File.t) ->
      ( file.path
      , Ocamldep_cache_.get_deps
          ocamldep_cache
          ~source_path:file.path
          build_dir
          package_id ))
    |> Path.Absolute.Map.of_list_exn
  in
  Ocamldep_cache_.store_deps deps build_dir package_id;
  Path.Absolute.Map.to_list deps
  |> List.map ~f:(fun (source_path, (deps : Alice_ocamldep.Deps.t)) ->
    let open Typed_op in
    let open Alice_error in
    match File.Source.of_path_by_extension source_path with
    | Error (`Unknown_extension _) ->
      panic
        [ Pp.textf
            "Tried to treat %S as source path but it has an unrecognized extension."
            (Alice_ui.path_to_string source_path)
        ]
    | Ok (`Ml direct_input) ->
      let indirect_inputs =
        List.map deps.inputs ~f:(fun dep ->
          match File.Compiled.of_path_by_extension_infer_role_from_name dep with
          | Ok (`Cmx cmx) -> `Cmx cmx
          | Ok (`Cmi cmi) -> `Cmi cmi
          | Ok _ ->
            panic
              [ Pp.textf
                  "Running ocamldep on %S produced build input %S whose extension is \
                   unexpected (expected either \".cmx\" or \".cmi\")."
                  (Alice_ui.path_to_string source_path)
                  (Alice_ui.path_to_string dep)
              ]
          | Error (`Unknown_extension _) ->
            panic
              [ Pp.textf
                  "Running ocamldep on %S produced build input %S whose extension is \
                   unrecognized."
                  (Alice_ui.path_to_string source_path)
                  (Alice_ui.path_to_string dep)
              ])
      in
      let source_file = Path.chop_prefix source_path ~prefix:(Dir.path dir) in
      let direct_output =
        Path.replace_extension source_file ~ext:".cmx"
        |> File.Compiled.cmx_infer_role_from_name
      in
      let indirect_output =
        Path.replace_extension source_file ~ext:".o"
        |> File.Compiled.o_infer_role_from_name
      in
      let matching_mli_file = Path.replace_extension source_path ~ext:".mli" in
      let interface_output_if_no_matching_mli_is_present =
        if File_ops.exists matching_mli_file
        then None
        else
          Some
            (Path.replace_extension source_file ~ext:".cmi"
             |> File.Compiled.cmi_infer_role_from_name)
      in
      `Compile_source
        { Compile_source.direct_input
        ; indirect_inputs
        ; direct_output
        ; indirect_output
        ; interface_output_if_no_matching_mli_is_present
        }
    | Ok (`Mli direct_input) ->
      let indirect_inputs =
        List.map deps.inputs ~f:(fun dep ->
          match File.Compiled.of_path_by_extension_infer_role_from_name dep with
          | Ok (`Cmi cmi) -> cmi
          | Ok _ ->
            panic
              [ Pp.textf
                  "Running ocamldep on %S produced build input %S whose extension is \
                   unexpected (expected either \".cmi\")."
                  (Alice_ui.path_to_string source_path)
                  (Alice_ui.path_to_string dep)
              ]
          | Error (`Unknown_extension _) ->
            panic
              [ Pp.textf
                  "Running ocamldep on %S produced build input %S whose extension is \
                   unrecognized."
                  (Alice_ui.path_to_string source_path)
                  (Alice_ui.path_to_string dep)
              ])
      in
      let direct_output =
        Path.chop_prefix source_path ~prefix:(Dir.path dir)
        |> Path.replace_extension ~ext:".cmi"
        |> File.Compiled.cmi_infer_role_from_name
      in
      `Compile_interface
        { Compile_interface.direct_input; indirect_inputs; direct_output })
;;

let path_mv path ~dst =
  let basename = Path.basename path in
  dst / basename
;;

let source_builds profile dir ~out_dir ~package =
  let ocamldep_cache = Ocamldep_cache.load ~out_dir ~package in
  let deps =
    Dir.contents dir
    |> List.filter ~f:(fun file ->
      File.is_regular_or_link file
      && (Path.has_extension file.path ~ext:".ml"
          || Path.has_extension file.path ~ext:".mli"))
    |> List.sort ~cmp:File.compare_by_path
    |> List.map ~f:(fun (file : _ File.t) ->
      file.path, Ocamldep_cache.get_deps ocamldep_cache file.path ~package)
    |> Path.Absolute.Map.of_list_exn
  in
  Ocamldep_cache.store_deps deps ~out_dir;
  Path.Absolute.Map.to_list deps
  |> List.map ~f:(fun (source_path, (deps : Alice_ocamldep.Deps.t)) ->
    let deps_inputs = List.map deps.inputs ~f:(fun input -> out_dir / input) in
    let inputs = Path.Absolute.Set.of_list (source_path :: deps_inputs) in
    let outputs =
      (out_dir / deps.output)
      ::
      (if Path.has_extension source_path ~ext:".ml"
       then [ Path.replace_extension source_path ~ext:".o" ]
       else [])
      |> List.map ~f:(path_mv ~dst:out_dir)
      |> Path.Absolute.Set.of_list
    in
    let command_out_path =
      (* Passing the output cm[xi] path to ocamlopt causes other output files to
         be generated in the same directory. *)
      let ext = if Path.has_extension source_path ~ext:".mli" then ".cmi" else ".cmx" in
      Path.replace_extension source_path ~ext |> path_mv ~dst:out_dir
    in
    { Origin.Build.inputs
    ; outputs
    ; commands =
        [ Profile.ocamlopt_command
            profile
            ~args:
              [ "-c"
              ; "-I"
              ; Path.to_filename out_dir
              ; "-o"
              ; Path.to_filename command_out_path
              ; Path.to_filename source_path
              ]
        ]
    })
;;

(* Given the path to the source file which will be the module root [root_ml]
   and a list of rules for compiling ocaml source files, computes an order of
   cmx(a) files from the output of given rules such that all dependencies of a
   file preceed that file. *)
let cmx_file_order ~root_ml ~out_dir source_builds =
  let ext = ".cmx" in
  let root_cmx = Path.replace_extension root_ml ~ext |> path_mv ~dst:out_dir in
  let plan = Build_graph.create source_builds ~outputs:[ root_cmx ] in
  let rec loop acc traverse =
    let module Traverse = Build_graph.Traverse in
    let cmx_outputs =
      Traverse.outputs traverse
      |> Path.Absolute.Set.filter ~f:(Path.has_extension ~ext)
      |> Path.Absolute.Set.to_list
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
let link_rule profile ~out_path ~cmx_deps_in_order kind =
  let o_paths = List.map cmx_deps_in_order ~f:(Path.replace_extension ~ext:".o") in
  let inputs = Path.Absolute.Set.of_list (cmx_deps_in_order @ o_paths) in
  let outputs =
    match kind with
    | `Exe -> Path.Absolute.Set.singleton out_path
    | `Lib ->
      (match Path.Absolute.extension out_path with
       | ".cmxa" -> ()
       | other ->
         Alice_error.panic
           [ Pp.textf
               "Unexpected extension for library filename. Expected .cmxa, got %s."
               other
           ]);
      Path.Absolute.Set.of_list
        [ out_path; Path.Absolute.replace_extension out_path ~ext:".a" ]
  in
  let extra_flags =
    match kind with
    | `Exe -> []
    | `Lib -> [ "-a" ]
  in
  { Origin.Build.inputs
  ; outputs
  ; commands =
      [ Profile.ocamlopt_command
          profile
          ~args:
            (extra_flags
             @ [ "-o"; Path.Absolute.to_filename out_path ]
             @ List.map cmx_deps_in_order ~f:Path.Absolute.to_filename)
      ]
  }
;;

let rules profile ~out_path ~root_ml ~source_builds ~out_dir kind =
  let cmx_deps_in_order = cmx_file_order ~root_ml ~out_dir source_builds in
  link_rule profile ~out_path ~cmx_deps_in_order kind :: source_builds
;;

module Package_build_planner = struct
  type build_plan = t

  type ('exe, 'lib) t =
    { package_typed : ('exe, 'lib) Package.Typed.t
    ; build_graph : Build_graph.t
    ; exe_path : Path.Absolute.t
    ; lib_cmxa_path : Path.Absolute.t
    }

  let create
    : type exe lib.
      Profile.t -> (exe, lib) Package.Typed.t -> out_dir:Path.Absolute.t -> (exe, lib) t
    =
    fun profile package_typed ~out_dir ->
    let package = Package.Typed.package package_typed in
    let name_str = Package.name package |> Package_name.to_string in
    let out_path_base = out_dir / Path.relative name_str in
    let src_dir = Package.src_dir_exn package in
    let exe_path =
      if Sys.win32 then Path.add_extension out_path_base ~ext:".exe" else out_path_base
    in
    let lib_cmxa_path = Path.add_extension out_path_base ~ext:".cmxa" in
    let source_builds =
      source_builds profile src_dir ~out_dir ~package:(Package.id package)
    in
    let lib_rules ~lib_root_ml =
      rules
        profile
        ~out_path:lib_cmxa_path
        ~root_ml:lib_root_ml
        ~source_builds
        ~out_dir
        `Lib
    in
    let exe_rules ~exe_root_ml =
      rules profile ~out_path:exe_path ~root_ml:exe_root_ml ~source_builds ~out_dir `Exe
    in
    let outputs, builds =
      match Package.Typed.type_ package_typed with
      | Exe_only ->
        [ exe_path ], exe_rules ~exe_root_ml:(src_dir.path / Package.exe_root_ml)
      | Lib_only ->
        [ lib_cmxa_path ], lib_rules ~lib_root_ml:(src_dir.path / Package.lib_root_ml)
      | Exe_and_lib ->
        ( [ exe_path; lib_cmxa_path ]
        , lib_rules ~lib_root_ml:(src_dir.path / Package.lib_root_ml)
          @ exe_rules ~exe_root_ml:(src_dir.path / Package.exe_root_ml) )
    in
    { package_typed
    ; build_graph = Build_graph.create builds ~outputs
    ; exe_path
    ; lib_cmxa_path
    }
  ;;

  let plan_exe ({ build_graph; exe_path; _ } : (true_t, _) t) =
    Build_graph.traverse build_graph ~output:exe_path |> Option.get
  ;;

  let plan_lib ({ build_graph; lib_cmxa_path; _ } : (_, true_t) t) =
    Build_graph.traverse build_graph ~output:lib_cmxa_path |> Option.get
  ;;

  let all_plans : type exe lib. (exe, lib) t -> build_plan list =
    fun t ->
    match Package.Typed.type_ t.package_typed with
    | Exe_only -> [ plan_exe t ]
    | Lib_only -> [ plan_lib t ]
    | Exe_and_lib -> [ plan_lib t; plan_exe t ]
  ;;

  let dot { build_graph; _ } = Build_graph.dot build_graph
end

let create_exe profile package_typed ~out_dir =
  Package_build_planner.create profile package_typed ~out_dir
  |> Package_build_planner.plan_exe
;;

let create_lib profile package_typed ~out_dir =
  Package_build_planner.create profile package_typed ~out_dir
  |> Package_build_planner.plan_lib
;;
