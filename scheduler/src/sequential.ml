open! Alice_stdlib
open Alice_hierarchy
open Alice_error
module File_ops = Alice_io.File_ops
module Build_plan = Alice_engine.Build_plan
module Traverse = Alice_engine.Build_plan.Traverse
module Log = Alice_log

(* Determines which files need to be (re)built. A file will be built if it is
   absent from [out_dir], or if it is present but it or one of its source
   dependencies has an older mtime than their counterpart in [src_dir]. *)
let files_to_build ~src_dir ~out_dir traverse =
  let rec loop traverse ~ancestors ~acc_files_to_build =
    match Traverse.origin traverse with
    | Source path ->
      let src_path = Path.concat src_dir path in
      let out_path = Path.concat out_dir path in
      let rebuild_ancestors =
        match File_ops.exists out_path with
        | false ->
          (* Source file is missing from output, so assume all ancestors need
             to be (re)built after it gets copied. *)
          true
        | true ->
          (* Source file already exists in the output, but it may have changed
             since it was last copied to the output, in which case all
             ancestors need to be rebuilt. *)
          let src_mtime = File_ops.mtime src_path in
          let out_mtime = File_ops.mtime out_path in
          src_mtime > out_mtime
      in
      if rebuild_ancestors
      then
        Path.Relative.Set.union acc_files_to_build (Path.Relative.Set.add path ancestors)
      else acc_files_to_build
    | Build build ->
      let non_existant_build_outputs =
        Path.Relative.Set.filter build.outputs ~f:(fun output ->
          let output_path_in_out_dir = Path.concat out_dir output in
          not (File_ops.exists output_path_in_out_dir))
      in
      let acc_files_to_build =
        (* Any build outputs that are missing from the output dir will be built. *)
        Path.Relative.Set.union acc_files_to_build non_existant_build_outputs
      in
      let ancestors = Path.Relative.Set.union build.outputs ancestors in
      List.fold_left
        (Traverse.deps traverse)
        ~init:acc_files_to_build
        ~f:(fun acc_files_to_build dep -> loop dep ~ancestors ~acc_files_to_build)
  in
  loop
    traverse
    ~ancestors:Path.Relative.Set.empty
    ~acc_files_to_build:Path.Relative.Set.empty
;;

let run ~src_dir ~out_dir ~package traverse =
  let panic_context () =
    [ Pp.textf "src_dir: %s\n" (Alice_ui.path_to_string src_dir)
    ; Pp.textf "out_dir: %s\n" (Alice_ui.path_to_string out_dir)
    ]
  in
  let rec loop ~acc_files_to_build traverse =
    let acc_files_to_build =
      List.fold_left
        (Traverse.deps traverse)
        ~init:acc_files_to_build
        ~f:(fun acc_files_to_build dep -> loop ~acc_files_to_build dep)
    in
    let need_to_build =
      not
        (Path.Relative.Set.is_empty
           (Path.Relative.Set.inter acc_files_to_build (Traverse.outputs traverse)))
    in
    match need_to_build with
    | false -> acc_files_to_build
    | true ->
      (match Traverse.origin traverse with
       | Source path ->
         Log.info
           ~package
           [ Pp.textf "Copying source file: %s" (Alice_ui.path_to_string path) ];
         File_ops.cp_f ~src:(Path.concat src_dir path) ~dst:Path.current_dir
       | Build (build : Build_plan.Build.t) ->
         Log.info
           ~package
           [ Pp.textf
               "Building targets: %s"
               (Path.Relative.Set.to_list build.outputs
                |> List.map ~f:Alice_ui.path_to_string
                |> String.concat ~sep:", ")
           ];
         Path.Relative.Set.iter build.inputs ~f:(fun path ->
           if not (File_ops.exists path)
           then
             Alice_error.panic
               (Pp.textf "Missing input file: %s\n" (Alice_ui.path_to_string path)
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
      Path.Relative.Set.diff acc_files_to_build (Traverse.outputs traverse)
  in
  File_ops.mkdir_p out_dir;
  let files_to_build = files_to_build ~src_dir ~out_dir traverse in
  let remaining_files_to_build =
    File_ops.with_working_dir out_dir ~f:(fun () ->
      loop ~acc_files_to_build:files_to_build traverse)
  in
  if not (Path.Relative.Set.is_empty remaining_files_to_build)
  then
    Alice_error.panic
      (Pp.textf
         "Not all files were built. Missing files: %s"
         (Path.Relative.Set.to_dyn remaining_files_to_build |> Dyn.to_string)
       :: panic_context ())
;;
