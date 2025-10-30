open! Alice_stdlib
open Alice_hierarchy
open Alice_package
open Alice_error
module File_ops = Alice_io.File_ops
module Log = Alice_log

module Sequential = struct
  (* Determines which files need to be (re)built. A file needs to be rebuilt if
     any of its dependencies need to be rebuilt, or if its mtime is earlier than
     any of its source dependencies. *)
  let files_to_build build_plan =
    let rec loop build_plan =
      match Build_plan.origin build_plan with
      | Source source ->
        (* Source files are not built. *)
        File_ops.mtime source, Path.Absolute.Set.empty
      | Build build ->
        let deps = Build_plan.deps build_plan in
        let latest_mtime, to_rebuild =
          List.fold_left
            deps
            ~init:(Float.neg_infinity, Path.Absolute.Set.empty)
            ~f:(fun (acc_latest_mtime, acc_to_rebuild) dep ->
              let latest_mtime, to_rebuild = loop dep in
              ( Float.max latest_mtime acc_latest_mtime
              , Path.Absolute.Set.union to_rebuild acc_to_rebuild ))
        in
        let to_rebuild =
          match Path.Absolute.Set.is_empty to_rebuild with
          | false ->
            (* If any dependencies need rebuilding, all our out outputs need rebuilding too. *)
            Path.Absolute.Set.union build.outputs to_rebuild
          | true ->
            (* Rebuild all the outputs which either don't exist, or whose mtime
               is earlier than the latest mtime among source files which the
               output depends on. *)
            Path.Absolute.Set.filter build.outputs ~f:(fun output ->
              (not (File_ops.exists output)) || File_ops.mtime output < latest_mtime)
        in
        latest_mtime, to_rebuild
    in
    loop build_plan |> snd
  ;;

  let eval_build_plan build_plan package ~out_dir =
    let open Alice_ui in
    let src_dir = Package.src_dir_path package in
    let panic_context () =
      [ Pp.textf "src_dir: %s\n" (path_to_string src_dir)
      ; Pp.textf "out_dir: %s\n" (path_to_string out_dir)
      ]
    in
    let print_compiling_message =
      println_once
        (verb_message `Compiling (Package_id.name_v_version_string (Package.id package)))
    in
    let rec loop ~acc_files_to_build build_plan =
      let acc_files_to_build =
        List.fold_left
          (Build_plan.deps build_plan)
          ~init:acc_files_to_build
          ~f:(fun acc_files_to_build dep -> loop ~acc_files_to_build dep)
      in
      let need_to_build =
        not
          (Path.Absolute.Set.is_empty
             (Path.Absolute.Set.inter acc_files_to_build (Build_plan.outputs build_plan)))
      in
      match need_to_build with
      | false -> acc_files_to_build
      | true ->
        (match Build_plan.origin build_plan with
         | Source _ -> ()
         | Build (build : Origin.Build.t) ->
           print_compiling_message ();
           Log.info
             ~package_id:(Package.id package)
             [ Pp.textf
                 "Building targets: %s"
                 (Path.Absolute.Set.to_list build.outputs
                  |> List.map ~f:path_to_string
                  |> String.concat ~sep:", ")
             ];
           Path.Absolute.Set.iter build.inputs ~f:(fun path ->
             if not (File_ops.exists path)
             then
               Alice_error.panic
                 (Pp.textf "Missing input file: %s\n" (path_to_string path)
                  :: panic_context ()));
           List.iter build.commands ~f:(fun command ->
             let status =
               match Alice_io.Process.Blocking.run_command command with
               | Ok status -> status
               | Error `Prog_not_available ->
                 panic [ Pp.textf "Can't find program: %s" command.prog ]
             in
             match status with
             | Exited 0 -> ()
             | _ ->
               Alice_error.panic
                 (Pp.textf "Command failed: %s\n" (Command.to_string command)
                  :: panic_context ())));
        Path.Absolute.Set.diff acc_files_to_build (Build_plan.outputs build_plan)
    in
    File_ops.mkdir_p out_dir;
    let files_to_build = files_to_build build_plan in
    let remaining_files_to_build = loop ~acc_files_to_build:files_to_build build_plan in
    if not (Path.Absolute.Set.is_empty remaining_files_to_build)
    then
      Alice_error.panic
        (Pp.textf
           "Not all files were built. Missing files: %s"
           (Path.Absolute.Set.to_dyn remaining_files_to_build |> Dyn.to_string)
         :: panic_context ())
  ;;
end
