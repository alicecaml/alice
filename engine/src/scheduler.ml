open! Alice_stdlib
open Alice_hierarchy
open Alice_package
open Alice_error
module File_ops = Alice_io.File_ops
module Log = Alice_log
module Build_plan = Build_graph.Build_plan
module Generated_file = Typed_op.Generated_file
module Package_with_deps = Dependency_graph.Package_with_deps
module Limit = Alice_io.Concurrency.Limit
module Io_ctx = Alice_io.Io_ctx

module Package_built = struct
  type t =
    | Rebuilt
    | Not_rebuilt

  let any_rebuilt ts =
    List.exists ts ~f:(function
      | Rebuilt -> true
      | Not_rebuilt -> false)
  ;;
end

module Generated_public_interface_to_open = struct
  type t =
    { output_path : Absolute_path.non_root_t
    ; public_interface_to_open : Public_interface_to_open.t
    }
end

module Action = struct
  type t =
    | Command of Command.t
    | Generated_public_interface_to_open of Generated_public_interface_to_open.t

  let run t proc_mgr =
    match t with
    | Command command ->
      Alice_io.Process.Eio.run_command proc_mgr command
      |> Alice_io.Process.Eio.result_ok_or_exn
    | Generated_public_interface_to_open { output_path; public_interface_to_open } ->
      (* TODO write the public interface file with eio *)
      Log.debug
        [ Pp.textf
            "Generating public interface source file: %s"
            (Absolute_path.to_filename output_path)
        ];
      File_ops.write_text_file
        output_path
        (Public_interface_to_open.source_code public_interface_to_open)
  ;;
end

let op_action op package_with_deps profile build_dir ocaml_compiler =
  let open Typed_op.File in
  let package = Package_with_deps.package package_with_deps in
  let transitive_dep_libs =
    Package_with_deps.transitive_dependency_closure_excluding_package package_with_deps
  in
  let immediate_dep_libs =
    Package_with_deps.immediate_deps_in_dependency_order package_with_deps
  in
  let lib_open_args =
    List.concat_map immediate_dep_libs ~f:(fun dep_lib ->
      let module_name =
        Package_with_deps.name dep_lib |> Module_name.public_interface_to_open
      in
      [ "-open"; Module_name.to_string_uppercase_first_letter module_name ])
  in
  let lib_include_args =
    List.concat_map transitive_dep_libs ~f:(fun dep_lib ->
      let package_id = Package.Typed.package dep_lib |> Package.id in
      [ "-I"
      ; Build_dir.package_public_dir build_dir package_id profile
        |> Absolute_path.to_filename
      ])
  in
  let lib_cmxa_files =
    List.map transitive_dep_libs ~f:(fun dep_lib ->
      let package_id = Package.Typed.package dep_lib |> Package.id in
      let public = Build_dir.package_public_dir build_dir package_id profile in
      public / Linked.path Linked.lib_cmxa |> Absolute_path.to_filename)
  in
  let package_id = Package.id package in
  let private_ = Build_dir.package_private_dir build_dir package_id profile in
  let public = Build_dir.package_public_dir build_dir package_id profile in
  let public_for_lsp =
    Build_dir.package_public_for_lsp_dir build_dir package_id profile
  in
  let compiled_absolute_filename compiled =
    let compiled = Typed_op.File.Compiled.generated_file_compiled compiled in
    Build_dir.package_generated_file_compiled build_dir package_id profile compiled
    |> Absolute_path.to_filename
  in
  let executable = Build_dir.package_executable_dir build_dir package_id profile in
  let package_pack = Typed_op.Pack.of_package_name (Package.name package) in
  let stop_after_typing_args = [ "-stop-after"; "typing" ] in
  let compile_args_common_not_lsp =
    [ "-I"
    ; Absolute_path.to_filename private_
    ; "-for-pack"
    ; Typed_op.Pack.module_name package_pack
      |> Module_name.to_string_uppercase_first_letter
    ]
  in
  let compile_args_common_lsp =
    [ (* Open this package's own internal module pack so modules with the same name
         as the package are still visible when generating a different (and largely
         unrelated!) module also named after the package. *)
      "-open"
    ; Module_name.internal_modules (Package.name package)
      |> Module_name.to_string_uppercase_first_letter
    ; (* The package's own public directory must be part of the search
         path so its internal module package can be opened. *)
      "-I"
    ; Absolute_path.to_filename public
    ]
  in
  match (op : Typed_op.t) with
  | Compile_source { source_input; cmx_output; stop_after_typing; _ } ->
    let stop_after_typing_args =
      if stop_after_typing then stop_after_typing_args else []
    in
    let lsp_output_args =
      match Typed_op.File.Compiled.visibility cmx_output with
      | Public_for_lsp ->
        compile_args_common_lsp
        @ [ (* Include the public_for_lsp directory in the search path so packages
               with a lib.mli file can have their <package>.cmx file compiled
               against an already-existing <package>.cmi file in public_for_lsp. *)
            "-I"
          ; Absolute_path.to_filename public_for_lsp
          ]
      | _ -> compile_args_common_not_lsp
    in
    Action.Command
      (Profile.ocaml_compiler_command
         profile
         ocaml_compiler
         ~args:
           (lib_include_args
            @ lib_open_args
            @ stop_after_typing_args
            @ lsp_output_args
            @ [ "-c"
              ; "-bin-annot" (* Needed for LSP *)
              ; "-o"
              ; compiled_absolute_filename cmx_output
              ; "-impl"
              ; Absolute_path.to_filename @@ Source.path source_input
              ]))
  | Compile_interface { interface_input; cmi_output; stop_after_typing; _ } ->
    let stop_after_typing_args =
      if stop_after_typing then stop_after_typing_args else []
    in
    let lsp_output_args =
      match Typed_op.File.Compiled.visibility cmi_output with
      | Public_for_lsp -> compile_args_common_lsp
      | _ -> compile_args_common_not_lsp
    in
    Command
      (Profile.ocaml_compiler_command
         profile
         ocaml_compiler
         ~args:
           (lib_include_args
            @ lib_open_args
            @ stop_after_typing_args
            @ lsp_output_args
            @ [ "-c"
              ; "-bin-annot" (* Needed for LSP *)
              ; "-o"
              ; compiled_absolute_filename cmi_output
              ; "-intf"
              ; Source.path interface_input |> Absolute_path.to_filename
              ]))
  | Pack_library { cmx_inputs; pack; _ } ->
    if not (Typed_op.Pack.equal pack package_pack)
    then
      panic
        [ Pp.textf
            "Tried to generate pack module for package %S but we're currently building a \
             different package (%S)."
            (Package_name.to_string @@ Typed_op.Pack.package_name pack)
            (Package_name.to_string @@ Typed_op.Pack.package_name package_pack)
        ];
    Command
      (Profile.ocaml_compiler_command
         profile
         ocaml_compiler
         ~args:
           (List.map cmx_inputs ~f:compiled_absolute_filename
            @ [ "-pack"; "-o"; compiled_absolute_filename (Typed_op.Pack.cmx_file pack) ]
           ))
  | Generate_public_interface_to_open { ml_output } ->
    let output_path =
      Build_dir.package_generated_file
        build_dir
        package_id
        profile
        (Typed_op.File.Generated_source.generated_file ml_output)
    in
    let public_interface_to_open =
      Public_interface_to_open.of_package_with_deps package_with_deps
    in
    Generated_public_interface_to_open { output_path; public_interface_to_open }
  | Compile_public_interface_to_open { generated_source_input; cmx_output; _ } ->
    let impl =
      Build_dir.package_generated_source_dir build_dir package_id profile
      / Typed_op.File.Generated_source.path generated_source_input
    in
    Action.Command
      (Profile.ocaml_compiler_command
         profile
         ocaml_compiler
         ~args:
           [ "-I"
           ; Absolute_path.to_filename public
           ; "-c"
           ; "-o"
           ; compiled_absolute_filename cmx_output
           ; "-impl"
           ; Absolute_path.to_filename impl
           ])
  | Link_library { cmx_inputs; cmxa_output; _ } ->
    Command
      (Profile.ocaml_compiler_command
         profile
         ocaml_compiler
         ~args:
           (lib_include_args
            @ List.map cmx_inputs ~f:compiled_absolute_filename
            @ [ "-a"
              ; "-o"
              ; Absolute_path.to_filename @@ (public / Linked.path cmxa_output)
              ]))
  | Link_executable { cmx_inputs; exe_output } ->
    Command
      (Profile.ocaml_compiler_command
         profile
         ocaml_compiler
         ~args:
           (lib_cmxa_files
            @ List.map cmx_inputs ~f:compiled_absolute_filename
            @ [ "-o"; Absolute_path.to_filename @@ (executable / Linked.path exe_output) ]
           ))
;;

module File_is_built = struct
  type t =
    { condvar : Eio.Condition.t
    ; state : bool ref
    ; file : Generated_file.t
    }

  let create file = { condvar = Eio.Condition.create (); state = ref false; file }

  let wait { condvar; state; file = _ } =
    if not !state
    then Eio.Condition.loop_no_mutex condvar (fun () -> if !state then Some () else None)
  ;;

  let wait_multi ts = List.iter ts ~f:wait

  let broadcast { condvar; state; file = _ } =
    state := true;
    Eio.Condition.broadcast condvar
  ;;

  let broadcast_multi ts = List.iter ts ~f:broadcast
end

module Task = struct
  (* A computation that can perform side effects and knows the tasks that must
     be completed before this task can start. *)
  type t =
    { package_id : Package_id.t
    ; action : Action.t
    ; build_plan : Build_plan.t
    ; build_dir : Build_dir.t
    ; profile : Profile.t
    ; finished : File_is_built.t list
    ; deps_finished : File_is_built.t list
    }

  let assert_expected_files_exist { package_id; build_plan; build_dir; profile; _ } =
    let open Alice_ui in
    let outputs = Build_plan.outputs build_plan in
    Log.info
      ~package_id
      [ Pp.textf
          "Building targets: %s"
          (Generated_file.Set.to_list outputs
           |> List.map ~f:(fun gen_file ->
             Generated_file.path gen_file |> basename_to_string)
           |> String.concat ~sep:", ")
      ];
    (match Build_plan.source_input build_plan with
     | None -> ()
     | Some source_input ->
       if not (File_ops.exists source_input)
       then
         Alice_error.panic
           [ Pp.textf "Missing source file: %s" (absolute_path_to_string source_input) ]);
    List.iter (Build_plan.generated_inputs build_plan) ~f:(fun generated_file ->
      let compiled_path =
        Build_dir.package_generated_file build_dir package_id profile generated_file
      in
      if not (File_ops.exists compiled_path)
      then
        Alice_error.panic
          [ Pp.textf
              "Missing file which should have been compiled by this point: %s"
              (absolute_path_to_string compiled_path)
          ])
  ;;

  let run t (io_ctx : _ Io_ctx.t) =
    File_is_built.wait_multi t.deps_finished;
    Limit.run io_ctx.limit ~f:(fun () ->
      assert_expected_files_exist t;
      Action.run t.action io_ctx);
    File_is_built.broadcast_multi t.finished
  ;;

  let run_multi ts io_ctx =
    List.map ts ~f:(fun t -> fun () -> run t io_ctx) |> Eio.Fiber.all
  ;;
end

(* Determines which files need to be (re)built. A file needs to be rebuilt if
   any of its dependencies need to be rebuilt, or if its mtime is earlier than
   any of its source dependencies. *)
let incremental_files_to_build build_plan package_id profile build_dir =
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
        let output_abs =
          Build_dir.package_generated_file build_dir package_id profile output
        in
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

let tasks_of_build_plans
      build_plans
      package_with_deps
      profile
      build_dir
      ocaml_compiler
      ~any_dep_rebuilt
  =
  let package = Dependency_graph.Package_with_deps.package package_with_deps in
  let package_id = Package.id package in
  let make_tasks ~files_to_build ~files_are_built build_plan =
    let rec loop ~files_to_build ~tasks_rev build_plan =
      let remaining_files_to_build, tasks_rev =
        List.fold_left
          (Build_plan.deps build_plan)
          ~init:(files_to_build, tasks_rev)
          ~f:(fun (files_to_build, tasks_rev) dep ->
            let files_to_build, tasks_rev = loop ~files_to_build ~tasks_rev dep in
            files_to_build, tasks_rev)
      in
      let outputs = Build_plan.outputs build_plan in
      let need_to_build =
        not
          (Generated_file.Set.is_empty
             (Generated_file.Set.inter remaining_files_to_build outputs))
      in
      match need_to_build with
      | false -> remaining_files_to_build, tasks_rev
      | true ->
        let action =
          op_action
            (Build_plan.op build_plan)
            package_with_deps
            profile
            build_dir
            ocaml_compiler
        in
        let deps_finished =
          Build_plan.deps build_plan
          |> List.map ~f:Build_plan.outputs
          |> Generated_file.Set.union_all
          |> Generated_file.Set.to_list
          |> List.map ~f:(fun output ->
            Generated_file.Map.find_opt output files_are_built)
          |> List.filter_opt
        in
        let finished =
          Generated_file.Set.to_list outputs
          |> List.map ~f:(fun output ->
            Generated_file.Map.find_opt output files_are_built)
          |> List.filter_opt
        in
        let task =
          { Task.package_id
          ; action
          ; build_plan
          ; build_dir
          ; profile
          ; finished
          ; deps_finished
          }
        in
        let remaining_files_to_build =
          Generated_file.Set.diff remaining_files_to_build (Build_plan.outputs build_plan)
        in
        remaining_files_to_build, task :: tasks_rev
    in
    let remaining_files_to_build, tasks_rev =
      loop ~files_to_build ~tasks_rev:[] build_plan
    in
    remaining_files_to_build, List.rev tasks_rev
  in
  Build_dir.package_dirs build_dir package_id profile |> List.iter ~f:File_ops.mkdir_p;
  let files_to_build =
    if any_dep_rebuilt
    then
      (* At least one of this package's dependencies was just rebuilt.
         Rebuilt this entire package. *)
      List.fold_left build_plans ~init:Generated_file.Set.empty ~f:(fun acc build_plan ->
        Generated_file.Set.union acc (Build_plan.transitive_closure_outputs build_plan))
    else
      (* No deps were rebuilt, so only rebuilt the artifacts which are
         missing or whose inputs have changed since the last build. *)
      List.fold_left build_plans ~init:Generated_file.Set.empty ~f:(fun acc build_plan ->
        incremental_files_to_build build_plan package_id profile build_dir
        |> Generated_file.Set.union acc)
  in
  if Generated_file.Set.is_empty files_to_build
  then []
  else (
    let files_are_built =
      Generated_file.Set.to_list files_to_build
      |> List.map ~f:(fun file -> file, File_is_built.create file)
      |> Generated_file.Map.of_list_exn
    in
    let remaining_files_to_build_should_be_empty, tasks =
      List.fold_left
        build_plans
        ~init:(files_to_build, [])
        ~f:(fun (files_to_build, all_tasks) build_plan ->
          let remaining_files_to_build, tasks =
            make_tasks ~files_to_build ~files_are_built build_plan
          in
          remaining_files_to_build, all_tasks @ tasks)
    in
    if not (Generated_file.Set.is_empty remaining_files_to_build_should_be_empty)
    then
      Alice_error.panic
        [ Pp.textf
            "Not all files were built. Missing files: %s"
            (Generated_file.Set.to_dyn remaining_files_to_build_should_be_empty
             |> Dyn.to_string)
        ];
    tasks)
;;

let eval_build_plans
      io_ctx
      build_plans
      package_with_deps
      profile
      build_dir
      ocaml_compiler
      ~any_dep_rebuilt
  =
  let open Alice_ui in
  let tasks =
    tasks_of_build_plans
      build_plans
      package_with_deps
      profile
      build_dir
      ocaml_compiler
      ~any_dep_rebuilt
  in
  match tasks with
  | [] -> Package_built.Not_rebuilt
  | tasks ->
    println
      (verb_message
         `Compiling
         (Package_id.name_v_version_string (Package_with_deps.id package_with_deps)));
    Task.run_multi tasks io_ctx;
    Rebuilt
;;
