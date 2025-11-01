open! Alice_stdlib
open Alice_hierarchy
open Alice_package
open Alice_error
module File_ops = Alice_io.File_ops
module Log = Alice_log
module Build_plan = Build_graph.Build_plan
module Generated_file = Typed_op.Generated_file

let op_command op package profile build_dir ~dep_libs =
  let open Typed_op.File in
  let lib_include_args =
    List.concat_map dep_libs ~f:(fun dep_lib ->
      let package_id = Package.Typed.package dep_lib |> Package.id in
      let dep_lib_dir = Build_dir.package_lib_dir build_dir package_id profile in
      let dep_internal_dir =
        Build_dir.package_internal_dir build_dir package_id profile
      in
      [ "-I"
      ; Path.Absolute.to_filename dep_lib_dir
      ; "-I"
      ; Path.Absolute.to_filename dep_internal_dir
      ])
  in
  let lib_cmxa_files =
    List.map dep_libs ~f:(fun dep_lib ->
      let package_id = Package.Typed.package dep_lib |> Package.id in
      let dep_lib_dir = Build_dir.package_lib_dir build_dir package_id profile in
      dep_lib_dir / Linked.path Linked.lib_cmxa |> Path.to_filename)
  in
  let package_id = Package.id package in
  let abs_path_of_gen_file =
    Build_dir.package_generated_file build_dir package_id profile
  in
  let internal_dir = Build_dir.package_internal_dir build_dir package_id profile in
  let lib_dir = Build_dir.package_lib_dir build_dir package_id profile in
  let compile_source_or_interface direct_input direct_output =
    Profile.ocamlopt_command
      profile
      ~args:
        (lib_include_args
         @ [ "-I"
           ; internal_dir |> Path.Absolute.to_filename
           ; "-c"
           ; "-o"
           ; Compiled.generated_file direct_output
             |> abs_path_of_gen_file
             |> Path.Absolute.to_filename
           ; Source.path direct_input |> Path.Absolute.to_filename
           ])
  in
  match (op : Typed_op.t) with
  | Compile_source { direct_input; direct_output; _ } ->
    compile_source_or_interface direct_input direct_output
  | Compile_interface { direct_input; direct_output; _ } ->
    compile_source_or_interface direct_input direct_output
  | Link_library { direct_inputs; direct_output; _ } ->
    Profile.ocamlopt_command
      profile
      ~args:
        (lib_include_args
         @ [ "-I"
           ; internal_dir |> Path.Absolute.to_filename
           ; "-I"
           ; lib_dir |> Path.Absolute.to_filename
           ; "-a"
           ; "-o"
           ; Linked.generated_file direct_output
             |> abs_path_of_gen_file
             |> Path.Absolute.to_filename
           ]
         @ lib_cmxa_files
         @ List.map direct_inputs ~f:(fun compiled ->
           Compiled.generated_file compiled
           |> abs_path_of_gen_file
           |> Path.Absolute.to_filename))
  | Link_executable { direct_inputs; direct_output } ->
    Profile.ocamlopt_command
      profile
      ~args:
        (lib_include_args
         @ [ "-I"
           ; internal_dir |> Path.Absolute.to_filename
           ; "-I"
           ; lib_dir |> Path.Absolute.to_filename (* so exe can depend on library *)
           ; "-o"
           ; Linked.generated_file direct_output
             |> abs_path_of_gen_file
             |> Path.Absolute.to_filename
           ]
         @ lib_cmxa_files
         @ List.map direct_inputs ~f:(fun compiled ->
           Compiled.generated_file compiled
           |> abs_path_of_gen_file
           |> Path.Absolute.to_filename))
;;

module Sequential = struct
  (* Determines which files need to be (re)built. A file needs to be rebuilt if
     any of its dependencies need to be rebuilt, or if its mtime is earlier than
     any of its source dependencies. *)
  let files_to_build build_plan abs_path_of_gen_file =
    let rec loop build_plan =
      let deps = Build_plan.deps build_plan in
      let to_rebuild =
        List.fold_left deps ~init:Generated_file.Set.empty ~f:(fun acc_to_rebuild dep ->
          let to_rebuild = loop dep in
          Generated_file.Set.union to_rebuild acc_to_rebuild)
      in
      match Generated_file.Set.is_empty to_rebuild with
      | false ->
        (* If any dependencies need rebuilding, all our out outputs need rebuilding too. *)
        Generated_file.Set.union (Build_plan.outputs build_plan) to_rebuild
      | true ->
        (* Rebuild all the outputs which either don't exist, or whose mtime
           is earlier than the latest mtime among source files which the
           output depends on. *)
        Generated_file.Set.filter (Build_plan.outputs build_plan) ~f:(fun output ->
          let output_abs = abs_path_of_gen_file output in
          match File_ops.exists output_abs with
          | false ->
            (* File doesn't exist. Build it! *)
            true
          | true ->
            (* File exists. If it has a source file, compare the source
                 file's mtime with this file's mtime. *)
            (match Build_plan.source_input build_plan with
             | None ->
               (* No source dependency, so no need ot rebuild. *)
               false
             | Some source -> File_ops.mtime output_abs < File_ops.mtime source))
    in
    loop build_plan
  ;;

  let eval_build_plan build_plans package profile build_dir ~dep_libs =
    let open Alice_ui in
    let abs_path_of_gen_file =
      Build_dir.package_generated_file build_dir (Package.id package) profile
    in
    let src_dir = Package.src_dir_path package in
    let panic_context () =
      (* Information to help debug package build failures. *)
      let out_dir = Build_dir.package_base_dir build_dir (Package.id package) profile in
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
          (Generated_file.Set.is_empty
             (Generated_file.Set.inter acc_files_to_build (Build_plan.outputs build_plan)))
      in
      match need_to_build with
      | false -> acc_files_to_build
      | true ->
        print_compiling_message ();
        let outputs = Build_plan.outputs build_plan in
        Log.info
          ~package_id:(Package.id package)
          [ Pp.textf
              "Building targets: %s"
              (Generated_file.Set.to_list outputs
               |> List.map ~f:(fun gen_file ->
                 Generated_file.path gen_file |> path_to_string)
               |> String.concat ~sep:", ")
          ];
        (match Build_plan.source_input build_plan with
         | None -> ()
         | Some source_input ->
           if not (File_ops.exists source_input)
           then
             Alice_error.panic
               (Pp.textf "Missing source file: %s\n" (path_to_string source_input)
                :: panic_context ()));
        List.iter (Build_plan.compiled_inputs build_plan) ~f:(fun compiled ->
          let compiled_path = abs_path_of_gen_file (Generated_file.Compiled compiled) in
          if not (File_ops.exists compiled_path)
          then
            Alice_error.panic
              (Pp.textf
                 "Missing file which should have been compiled by this point: %s\n"
                 (path_to_string compiled_path)
               :: panic_context ()));
        let command =
          op_command (Build_plan.op build_plan) package profile build_dir ~dep_libs
        in
        (let status =
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
              :: panic_context ()));
        Generated_file.Set.diff acc_files_to_build (Build_plan.outputs build_plan)
    in
    Build_dir.package_dirs build_dir (Package.id package) profile
    |> List.iter ~f:File_ops.mkdir_p;
    let files_to_build =
      List.fold_left build_plans ~init:Generated_file.Set.empty ~f:(fun acc build_plan ->
        files_to_build build_plan abs_path_of_gen_file |> Generated_file.Set.union acc)
    in
    let remaining_files_to_build =
      List.fold_left
        build_plans
        ~init:files_to_build
        ~f:(fun acc_files_to_build build_plan -> loop ~acc_files_to_build build_plan)
    in
    if not (Generated_file.Set.is_empty remaining_files_to_build)
    then
      Alice_error.panic
        (Pp.textf
           "Not all files were built. Missing files: %s"
           (Generated_file.Set.to_dyn remaining_files_to_build |> Dyn.to_string)
         :: panic_context ())
  ;;
end
