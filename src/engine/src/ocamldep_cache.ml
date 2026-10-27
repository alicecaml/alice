open! Alice_stdlib
open Alice_hierarchy
open Alice_package
module File_ops = Alice_io.File_ops
module Log = Alice_log
open Alice_ocaml_toolchain

type dep_table = Ocaml_toolchain.Deps.t Absolute_path.Non_root_map.t

type t =
  { dep_table : dep_table
  ; mtime : float
  ; package_id : Package_id.t
  ; build_dir : Build_dir.t
  }

let load build_dir compiler_backend package_id =
  let path =
    Build_dir.package_ocamldeps_cache_file build_dir package_id compiler_backend
  in
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

let store t compiler_backend (dep_table : dep_table) =
  let path =
    Build_dir.package_ocamldeps_cache_file t.build_dir t.package_id compiler_backend
  in
  File_ops.mkdir_p
    (Absolute_path.parent path |> Absolute_path.Root_or_non_root.assert_non_root);
  File_ops.with_out_channel path ~mode:`Bin ~f:(fun channel ->
    Marshal.to_channel channel dep_table [])
;;

let get_deps_batch t (build_config : Build_config.t) ~local_src_dir_path ~src_file_names =
  let path =
    Build_dir.package_ocamldeps_cache_file
      t.build_dir
      t.package_id
      build_config.compiler_backend
  in
  let src_file_names_to_compute_deps_for, known_deps =
    List.partition_map src_file_names ~f:(fun src_file_name ->
      let source_path = Absolute_path.concat_basename local_src_dir_path src_file_name in
      let source_mtime = File_ops.mtime source_path in
      if source_mtime > t.mtime
      then Left src_file_name
      else (
        match Absolute_path.Non_root_map.find_opt source_path t.dep_table with
        | Some deps -> Right (source_path, deps)
        | None ->
          (* Source file is absent from the cache. This is unusual because the
             source file is older than the cache. Run ocamldep to compute the
             result anyway. *)
          Log.warn
            ~package_id:t.package_id
            [ Pp.textf
                "The ocamldeps cache (%s) is newer than source file %S, however there is \
                 no entry in the ocamldeps cache for that source file."
                (Alice_ui.absolute_path_to_string path)
                (Alice_ui.absolute_path_to_string source_path)
            ];
          Left src_file_name))
  in
  let computed_deps =
    if Alice_log.is_enabled `Info
    then
      List.iter src_file_names_to_compute_deps_for ~f:(fun src_file_name ->
        Log.info
          ~package_id:t.package_id
          [ Pp.textf
              "Analyzing dependencies of file: %s"
              (Alice_ui.absolute_path_to_string
                 (Absolute_path.concat_basename local_src_dir_path src_file_name))
          ]);
    let deps =
      Ocaml_toolchain.depends_batch
        build_config.ocaml_toolchain
        build_config.compiler_backend
        build_config.num_jobs
        ~local_src_dir_path
        ~src_file_names:src_file_names_to_compute_deps_for
    in
    if Alice_log.is_enabled `Debug
    then
      List.iter deps ~f:(fun { Ocaml_toolchain.Deps.output; inputs } ->
        Alice_log.debug
          [ Pp.textf
              "Deps of %s: %s"
              (Basename.to_filename output)
              (List.map inputs ~f:Basename.to_filename |> String.concat ~sep:", ")
          ]);
    List.zip
      (List.map
         src_file_names_to_compute_deps_for
         ~f:(Absolute_path.concat_basename local_src_dir_path))
      deps
  in
  List.append known_deps computed_deps
;;
