open! Alice_stdlib
open Alice_hierarchy
open Alice_package
module File_ops = Alice_io.File_ops
module Log = Alice_log

type dep_table = Alice_ocamldep.Deps.t Absolute_path.Non_root_map.t

type t =
  { dep_table : dep_table
  ; mtime : float
  ; package_id : Package_id.t
  ; build_dir : Build_dir.t
  }

let load build_dir package_id =
  let path = Build_dir.package_ocamldeps_cache_file build_dir package_id in
  if File_ops.exists path
  then (
    Log.info
      ~package_id
      [ Pp.textf
          "Loading ocamldeps cache from: %s"
          (Alice_ui.absolute_path_to_string path)
      ];
    let dep_table =
      File_ops.with_in_channel path ~mode:`Bin ~f:(fun channel ->
        Marshal.from_channel channel)
    in
    let mtime = File_ops.mtime path in
    { dep_table; mtime; build_dir; package_id })
  else
    { dep_table = Absolute_path.Non_root_map.empty
    ; mtime = Float.neg_infinity
    ; build_dir
    ; package_id
    }
;;

let store t (dep_table : dep_table) =
  let path = Build_dir.package_ocamldeps_cache_file t.build_dir t.package_id in
  File_ops.mkdir_p
    (Absolute_path.parent path |> Absolute_path.Root_or_non_root.assert_non_root);
  File_ops.with_out_channel path ~mode:`Bin ~f:(fun channel ->
    Marshal.to_channel channel dep_table [])
;;

let get_deps t ocaml_compiler ~source_path =
  let path = Build_dir.package_ocamldeps_cache_file t.build_dir t.package_id in
  let source_mtime = File_ops.mtime source_path in
  let run_ocamldep () =
    Log.info
      ~package_id:t.package_id
      [ Pp.textf
          "Analyzing dependencies of file: %s"
          (Alice_ui.absolute_path_to_string source_path)
      ];
    Alice_ocamldep.native_deps ocaml_compiler source_path
  in
  if source_mtime > t.mtime
  then
    (* Source file is newer than the cache so we need to run ocamldep. *)
    run_ocamldep ()
  else (
    match Absolute_path.Non_root_map.find_opt source_path t.dep_table with
    | None ->
      (* Source file is absent from the cache. This is unusual because the
           source file is older than the cache. Run ocamldep to compute the
           result anyway. *)
      Log.warn
        ~package_id:t.package_id
        [ Pp.textf
            "The ocamldeps cache (%s) is newer than source file %S, however there is no \
             entry in the ocamldeps cache for that source file."
            (Alice_ui.absolute_path_to_string path)
            (Alice_ui.absolute_path_to_string source_path)
        ];
      run_ocamldep ()
    | Some deps -> deps)
;;
