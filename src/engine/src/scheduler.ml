open! Alice_stdlib
open Alice_hierarchy
open Alice_package
open Alice_error
open Alice_ocaml_toolchain
module File_ops = Alice_io.File_ops
module Log = Alice_log
module Build_plan = Build_graph.Build_plan
module Generated_file = Typed_op.Generated_file
module Package_with_deps = Dependency_graph.Package_with_deps
module Builtin_module = Alice_builtin_module
module Package_base_dir = Build_dir.Package_base_dir

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

  let equal t { output_path; public_interface_to_open } =
    Absolute_path.equal t.output_path output_path
    && Public_interface_to_open.equal t.public_interface_to_open public_interface_to_open
  ;;
end

module Action = struct
  type t =
    | Command of Command.t
    | Generated_public_interface_to_open of Generated_public_interface_to_open.t

  (* If the action can be done by the current process then do it immediately
     and return [`Done]. If the action requires spawning a process, return a thunk
     that will spawn the process when called, allowing the scheduler to control the
     maximum number of processes running in parallel. *)
  let run_or_defer_spawn_process t =
    match t with
    | Command command ->
      `Spawn
        (fun () ->
          match Alice_io.Process.run_command command with
          | Ok running -> running
          | Error (`Prog_not_available _) ->
            Alice_error.user_exn [ Pp.textf "Can't find program: %s" command.prog ])
    | Generated_public_interface_to_open { output_path; public_interface_to_open } ->
      Log.debug
        [ Pp.textf
            "Generating public interface source file: %s"
            (Absolute_path.to_filename output_path)
        ];
      File_ops.write_text_file
        output_path
        (Public_interface_to_open.source_code public_interface_to_open);
      `Done
  ;;

  let equal a b =
    match a, b with
    | Command a, Command b -> Command.equal a b
    | Command _, _ -> false
    | Generated_public_interface_to_open a, Generated_public_interface_to_open b ->
      Generated_public_interface_to_open.equal a b
    | Generated_public_interface_to_open _, _ -> false
  ;;
end

module Action_builder = struct
  open Typed_op.File

  type compile_args =
    { builtin_modules : string list
    ; lsp_only : string list
    ; non_lsp_only : string list
    ; stop_after_typing : string list
    }

  type dep_args =
    { cmxa_files : string list
    ; include_ : string list
    ; open_ : string list
    }

  type dirs =
    { private_ : Absolute_path.non_root_t
    ; public : Absolute_path.non_root_t
    ; public_for_lsp : Absolute_path.non_root_t
    ; executable : Absolute_path.non_root_t
    }

  (** All the information necessary to compute a build command from a
      [Typed_op.t]. Commands are generated in the context of building artifacts
      of a single package and it's assumed that all the package's dependencies
      have already been built when building the current package. *)
  type ('exe, 'lib) t =
    { package_with_deps : ('exe, 'lib) Package_with_deps.t
    ; package_base_dir : Package_base_dir.t
    ; build_config : Build_config.t
    ; compile_args : compile_args
    ; dep_args : dep_args
    ; dirs : dirs
    ; dep_closure_builtin_modules : Builtin_module.Set.t
    }

  let create
        package_with_deps
        package_base_dir
        (build_config : Build_config.t)
        ~built_artifacts_from_deps
    =
    let package = Package_with_deps.package package_with_deps in
    let transitive_dep_libs =
      Package_with_deps.transitive_dependency_closure_excluding_package package_with_deps
    in
    let dep_package_base_dir dep =
      let build_dir =
        match built_artifacts_from_deps with
        | false -> Package_base_dir.build_dir package_base_dir
        | true ->
          let dep_package = Package.Typed.package dep in
          Build_dir.of_project_root_path (Package.root dep_package)
      in
      Build_dir.package_base_dir_of_build_config
        build_dir
        (Package.Typed.id dep)
        build_config
    in
    let package_pack = Typed_op.Pack.of_package_name (Package.name package) in
    let dep_args =
      let cmxa_files =
        let transitive_dep_libs =
          Package_with_deps.transitive_dependency_closure_excluding_package
            package_with_deps
        in
        List.map transitive_dep_libs ~f:(fun dep_lib ->
          let public = dep_package_base_dir dep_lib |> Package_base_dir.public_dir in
          public / Linked.path Linked.lib_cmxa |> Absolute_path.to_filename)
      in
      let immediate_dep_libs =
        Package_with_deps.immediate_deps_in_dependency_order package_with_deps
      in
      let open_ =
        List.concat_map immediate_dep_libs ~f:(fun dep_lib ->
          let module_name =
            Package_with_deps.name dep_lib |> Module_name.public_interface_to_open
          in
          [ "-open"; Module_name.to_string_uppercase_first_letter module_name ])
      in
      let include_ =
        List.concat_map transitive_dep_libs ~f:(fun dep_lib ->
          let public = dep_package_base_dir dep_lib |> Package_base_dir.public_dir in
          [ "-I"; Absolute_path.to_filename public ])
      in
      { cmxa_files; open_; include_ }
    in
    let dirs : dirs =
      let private_ = Package_base_dir.private_dir package_base_dir in
      let public = Package_base_dir.public_dir package_base_dir in
      let public_for_lsp = Package_base_dir.public_for_lsp_dir package_base_dir in
      let executable = Package_base_dir.executable_dir package_base_dir in
      { private_; public; public_for_lsp; executable }
    in
    let compile_args =
      let builtin_modules =
        Package_with_deps.builtin_modules package_with_deps
        |> Builtin_module.Set.to_list
        |> List.concat_map ~f:(fun builtin_module ->
          [ "-I"; sprintf "+%s" (Builtin_module.to_string builtin_module) ])
      in
      let lsp_only =
        [ (* Open this package's own internal module pack so modules with the same name
             as the package are still visible when generating a different (and largely
             unrelated!) module also named after the package. *)
          "-open"
        ; Module_name.internal_modules (Package.name package)
          |> Module_name.to_string_uppercase_first_letter
        ; (* The package's own public directory must be part of the search
         path so its internal module package can be opened. *)
          "-I"
        ; Absolute_path.to_filename dirs.public
        ]
      in
      let non_lsp_only =
        [ "-I"
        ; Absolute_path.to_filename dirs.private_
        ; "-for-pack"
        ; Typed_op.Pack.module_name package_pack
          |> Module_name.to_string_uppercase_first_letter
        ]
      in
      let stop_after_typing = [ "-stop-after"; "typing" ] in
      { builtin_modules; lsp_only; non_lsp_only; stop_after_typing }
    in
    let dep_closure_builtin_modules =
      List.fold_left
        transitive_dep_libs
        ~init:(Package_with_deps.builtin_modules package_with_deps)
        ~f:(fun acc dep ->
          Builtin_module.Set.union acc (Package.Typed.builtin_modules dep))
    in
    { package_with_deps
    ; package_base_dir
    ; build_config
    ; dep_args
    ; compile_args
    ; dirs
    ; dep_closure_builtin_modules
    }
  ;;

  let compiled_absolute_filename t compiled =
    Package_base_dir.generated_file_compiled t.package_base_dir compiled
    |> Absolute_path.to_filename
  ;;

  let op_action t op : Action.t =
    match (op : Typed_op.t) with
    | Compile_ocaml_source { source_input; cmx_output; stop_after_typing; _ } ->
      let stop_after_typing_args =
        if stop_after_typing then t.compile_args.stop_after_typing else []
      in
      let lsp_output_args =
        match Typed_op.Generated_file.Compiled.visibility cmx_output with
        | Public_for_lsp ->
          t.compile_args.lsp_only
          @ [ (* Include the public_for_lsp directory in the search path so packages
               with a lib.mli file can have their <package>.cmx file compiled
               against an already-existing <package>.cmi file in public_for_lsp. *)
              "-I"
            ; Absolute_path.to_filename t.dirs.public_for_lsp
            ]
        | _ -> t.compile_args.non_lsp_only
      in
      Command
        (Profile.ocamlopt_command
           t.build_config.profile
           t.build_config.ocaml_toolchain
           ~args:
             (t.dep_args.include_
              @ t.dep_args.open_
              @ lsp_output_args
              @ stop_after_typing_args
              @ t.compile_args.builtin_modules
              @ [ "-c"
                ; "-bin-annot" (* Needed for LSP *)
                ; "-o"
                ; compiled_absolute_filename t cmx_output
                ; "-impl"
                ; Absolute_path.to_filename @@ Ocaml_source_or_interface.path source_input
                ]))
    | Compile_ocaml_interface { interface_input; cmi_output; stop_after_typing; _ } ->
      let stop_after_typing_args =
        if stop_after_typing then t.compile_args.stop_after_typing else []
      in
      let lsp_output_args =
        match Typed_op.Generated_file.Compiled.visibility cmi_output with
        | Public_for_lsp -> t.compile_args.lsp_only
        | _ -> t.compile_args.non_lsp_only
      in
      Command
        (Profile.ocamlopt_command
           t.build_config.profile
           t.build_config.ocaml_toolchain
           ~args:
             (t.dep_args.include_
              @ t.dep_args.open_
              @ stop_after_typing_args
              @ lsp_output_args
              @ t.compile_args.builtin_modules
              @ [ "-c"
                ; "-bin-annot" (* Needed for LSP *)
                ; "-o"
                ; compiled_absolute_filename t cmi_output
                ; "-intf"
                ; Ocaml_source_or_interface.path interface_input
                  |> Absolute_path.to_filename
                ]))
    | Compile_c_source { source_input; object_output } ->
      (* Arguments to tell the OCaml compiler to tell the C compiler (which
         it invokes) to put the compiled object file at the expected path: *)
      let output_args =
        [ "-ccopt"; "-o"; "-ccopt"; compiled_absolute_filename t object_output ]
      in
      Command
        (Profile.ocamlopt_command
           t.build_config.profile
           t.build_config.ocaml_toolchain
           ~args:
             ([ Absolute_path.to_filename @@ C_source.path source_input ] @ output_args))
    | Pack_library { cmx_inputs; pack; _ } ->
      let package_pack =
        Package_with_deps.name t.package_with_deps |> Typed_op.Pack.of_package_name
      in
      if not (Typed_op.Pack.equal pack package_pack)
      then
        panic
          [ Pp.textf
              "Tried to generate pack module for package %S but we're currently building \
               a different package (%S)."
              (Package_name.to_string @@ Typed_op.Pack.package_name pack)
              (Package_name.to_string @@ Typed_op.Pack.package_name package_pack)
          ];
      Command
        (Profile.ocamlopt_command
           t.build_config.profile
           t.build_config.ocaml_toolchain
           ~args:
             (List.map cmx_inputs ~f:(compiled_absolute_filename t)
              @ [ "-pack"
                ; "-o"
                ; compiled_absolute_filename t (Typed_op.Pack.cmx_file pack)
                ]))
    | Generate_public_interface_to_open { ml_output } ->
      let output_path =
        Package_base_dir.generated_file
          t.package_base_dir
          (Typed_op.File.Generated_ocaml_source.generated_file ml_output)
      in
      let public_interface_to_open =
        Public_interface_to_open.of_package_with_deps t.package_with_deps
      in
      Generated_public_interface_to_open { output_path; public_interface_to_open }
    | Compile_public_interface_to_open { generated_source_input; cmx_output; _ } ->
      let impl =
        Package_base_dir.generated_source_dir t.package_base_dir
        / Typed_op.File.Generated_ocaml_source.basename generated_source_input
      in
      Action.Command
        (Profile.ocamlopt_command
           t.build_config.profile
           t.build_config.ocaml_toolchain
           ~args:
             [ "-I"
             ; Absolute_path.to_filename t.dirs.public
             ; "-c"
             ; "-o"
             ; compiled_absolute_filename t cmx_output
             ; "-impl"
             ; Absolute_path.to_filename impl
             ])
    | Link_library { cmx_inputs; cmxa_output; compiled_c_inputs; _ } ->
      Command
        (Profile.ocamlopt_command
           t.build_config.profile
           t.build_config.ocaml_toolchain
           ~args:
             (t.dep_args.include_
              @ List.map compiled_c_inputs ~f:(compiled_absolute_filename t)
              @ List.map cmx_inputs ~f:(compiled_absolute_filename t)
              @ [ "-a"
                ; "-o"
                ; Absolute_path.to_filename @@ (t.dirs.public / Linked.path cmxa_output)
                ]))
    | Link_executable { cmx_inputs; exe_output; compiled_c_inputs } ->
      let builtin_module_args =
        Builtin_module.Set.to_list t.dep_closure_builtin_modules
        |> List.map ~f:(fun builtin_module ->
          Ocaml_toolchain.builtin_module_cmxa
            t.build_config.ocaml_toolchain
            builtin_module
          |> Absolute_path.to_filename)
      in
      Command
        (Profile.ocamlopt_command
           t.build_config.profile
           t.build_config.ocaml_toolchain
           ~args:
             (builtin_module_args
              @ t.dep_args.cmxa_files
              @ List.map compiled_c_inputs ~f:(compiled_absolute_filename t)
              @ List.map cmx_inputs ~f:(compiled_absolute_filename t)
              @ [ "-o"
                ; Absolute_path.to_filename @@ (t.dirs.executable / Linked.path exe_output)
                ]))
  ;;
end

(* Determines which files need to be (re)built. A file needs to be rebuilt if
   any of its dependencies need to be rebuilt, or if its mtime is earlier than
   any of its source dependencies. *)
let incremental_files_to_build build_plan package_base_dir =
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
        let output_abs = Package_base_dir.generated_file package_base_dir output in
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

module Action_graph = struct
  (* This DAG is keyed by [Typed_op] because each action will have a unique
     operation, and knows the operations of their dependencies. *)
  include Alice_dag.Make (Typed_op)

  module Entry = struct
    type t =
      { action : Action.t
      ; package_id : Package_id.t
      ; build_plan : Build_plan.t
      ; mutable remaining_children_to_build : int
      }

    let equal t { action; package_id; build_plan; remaining_children_to_build } =
      Action.equal t.action action
      && Package_id.equal t.package_id package_id
      && Build_plan.equal t.build_plan build_plan
      && Int.equal t.remaining_children_to_build remaining_children_to_build
    ;;

    let decrement_remaining_children_to_build t =
      t.remaining_children_to_build <- t.remaining_children_to_build - 1
    ;;

    let is_ready t =
      assert (t.remaining_children_to_build >= 0);
      t.remaining_children_to_build == 0
    ;;
  end

  type nonrec t = Entry.t t

  module Staging = struct
    include Staging

    let add_or_panic t name entry ~child_names =
      add_or_panic t name entry ~eq:Entry.equal ~child_names
    ;;
  end

  module Static_vec = struct
    (* A vector with a maximum capacity *)
    type 'a t =
      { array : 'a option array
      ; mutable cursor : int
      }

    let create capacity = { array = Array.make capacity None; cursor = 0 }
    let is_empty t = t.cursor == 0
    let is_full t = t.cursor == Array.length t.array

    let iter t ~f =
      for i = 0 to t.cursor - 1 do
        f (Option.get t.array.(i))
      done
    ;;

    let push t x =
      assert (not (is_full t));
      t.array.(t.cursor) <- Some x;
      t.cursor <- t.cursor + 1
    ;;

    let swap_remove t i =
      assert (i < t.cursor);
      t.cursor <- t.cursor - 1;
      if i != t.cursor then t.array.(i) <- t.array.(t.cursor)
    ;;

    let swap_remove_filter_map t ~f =
      let i = ref 0 in
      let ret = ref [] in
      while !i < t.cursor do
        match f (Option.get t.array.(!i)) with
        | Some x ->
          swap_remove t !i;
          ret := x :: !ret
        | None -> i := !i + 1
      done;
      !ret
    ;;
  end

  let log_build node =
    let open Alice_ui in
    let entry : Entry.t = Node.value node in
    let outputs = Build_plan.outputs entry.build_plan in
    Log.info
      ~package_id:entry.package_id
      [ Pp.textf
          "Building targets: %s"
          (Generated_file.Set.to_list outputs
           |> List.map ~f:(fun gen_file ->
             Generated_file.path gen_file |> basename_to_string)
           |> String.concat ~sep:", ")
      ]
  ;;

  let run_parallel (t : t) num_jobs =
    let open Alice_io in
    let num_jobs =
      match (num_jobs : Alice_io.Num_jobs.t) with
      | Limited limited -> limited
      | Unlimited -> num_nodes t
    in
    (* Nodes whose actions are currently running, along with a handle to the
       running processes. *)
    let running = Static_vec.create num_jobs in
    (* Nodes whose actions are ready to run, but which haven't been started yet. *)
    let ready = Queue.create () in
    let rec complete_node (node : Entry.t Node.t) =
      (* Entries maintain a count of the number of their children that still
         need to be built. Decrement the count for each parent of the node that
         was just built, and if any of the counts become zero then enqueue
         those parents as they are now ready to be built themselves. *)
      List.iter (Node.parents node) ~f:(fun parent ->
        let entry = Node.value parent in
        Entry.decrement_remaining_children_to_build entry;
        if Entry.is_ready entry then enqueue_node parent)
    and enqueue_node (node : Entry.t Node.t) =
      let entry = Node.value node in
      assert (Entry.is_ready entry);
      match Action.run_or_defer_spawn_process entry.action with
      | `Done ->
        log_build node;
        complete_node node
      | `Spawn spawn_thunk -> Queue.push (node, spawn_thunk) ready
    in
    let spawn node spawn_thunk =
      assert (not (Static_vec.is_full running));
      let process_running = spawn_thunk () in
      log_build node;
      Static_vec.push running (node, process_running)
    in
    let spawn_all_ready_up_to_job_limit () =
      while (not (Static_vec.is_full running)) && not (Queue.is_empty ready) do
        let node, spawn_thunk = Queue.take ready in
        spawn node spawn_thunk
      done
    in
    Seq.iter (leaves t) ~f:enqueue_node;
    spawn_all_ready_up_to_job_limit ();
    let exception Process_exited_non_zero of Process.Report.t in
    try
      while not (Static_vec.is_empty running) do
        Unix.sleepf 0.001;
        let complete_with_reports =
          Static_vec.swap_remove_filter_map running ~f:(fun (node, running_process) ->
            Option.map (Alice_io.Process.Running.poll running_process) ~f:(fun report ->
              node, report))
        in
        List.iter complete_with_reports ~f:(fun (_, report) ->
          if not (Process.Report.is_exit_0 report)
          then raise (Process_exited_non_zero report));
        List.iter complete_with_reports ~f:(fun (node, _) -> complete_node node);
        spawn_all_ready_up_to_job_limit ()
      done;
      assert (Queue.is_empty ready)
    with
    | Process_exited_non_zero report ->
      Static_vec.iter running ~f:(fun (_, running_process) ->
        Process.Running.kill running_process);
      Alice_error.user_exn
        [ Pp.textf "Command failed: %s" (Command.to_string_ignore_env report.command) ]
  ;;
end

let make_action_graph
      build_graph
      build_plans
      package_with_deps
      package_base_dir
      build_config
      ~any_dep_rebuilt
      ~built_artifacts_from_deps
  =
  let action_builder =
    Action_builder.create
      package_with_deps
      package_base_dir
      build_config
      ~built_artifacts_from_deps
  in
  let package_id = Dependency_graph.Package_with_deps.package_id package_with_deps in
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
        incremental_files_to_build build_plan package_base_dir
        |> Generated_file.Set.union acc)
  in
  if Generated_file.Set.is_empty files_to_build
  then None
  else (
    let all_ops =
      List.concat_map build_plans ~f:Build_plan.transitive_closure
      |> List.map ~f:Build_plan.op
      |> Typed_op.Set.of_list
    in
    let ops_that_need_to_run =
      Typed_op.Set.filter all_ops ~f:(fun op ->
        List.exists (Typed_op.outputs op) ~f:(fun output ->
          Generated_file.Set.mem output files_to_build))
    in
    let action_graph =
      Typed_op.Set.fold
        ops_that_need_to_run
        ~init:Action_graph.Staging.empty
        ~f:(fun op staging ->
          let build_plan = Build_graph.build_plan build_graph ~op in
          let child_names =
            Build_plan.deps build_plan
            |> List.filter_map ~f:(fun build_plan ->
              let op = Build_plan.op build_plan in
              if Typed_op.Set.mem op ops_that_need_to_run then Some op else None)
          in
          let action = Action_builder.op_action action_builder op in
          let entry =
            { Action_graph.Entry.action
            ; package_id
            ; build_plan
            ; remaining_children_to_build = List.length child_names
            }
          in
          Action_graph.Staging.add_or_panic staging op entry ~child_names)
      |> Action_graph.Staging.finalize_or_panic
    in
    Some action_graph)
;;

let run
  : type exe lib.
    (exe, lib) Build_graph.t
    -> (exe, lib) Package_with_deps.t
    -> Package_base_dir.t
    -> Build_config.t
    -> any_dep_rebuilt:bool
    -> built_artifacts_from_deps:bool
    -> Package_built.t
  =
  fun build_graph
    package_with_deps
    package_base_dir
    build_config
    ~any_dep_rebuilt
    ~built_artifacts_from_deps ->
  let open Alice_ui in
  let build_plans =
    match Package_with_deps.type_ package_with_deps with
    | Exe_only -> [ Build_graph.plan_exe build_graph ]
    | Lib_only -> [ Build_graph.plan_lib build_graph; Build_graph.plan_lsp build_graph ]
    | Exe_and_lib ->
      [ Build_graph.plan_lib build_graph
      ; Build_graph.plan_lsp build_graph
      ; Build_graph.plan_exe build_graph
      ]
  in
  match
    make_action_graph
      build_graph
      build_plans
      package_with_deps
      package_base_dir
      build_config
      ~any_dep_rebuilt
      ~built_artifacts_from_deps
  with
  | None -> Package_built.Not_rebuilt
  | Some action_graph ->
    println
      (verb_message
         `Compiling
         (Package_id.name_v_version_string (Package_with_deps.id package_with_deps)));
    Package_base_dir.dirs package_base_dir |> List.iter ~f:File_ops.mkdir_p;
    Action_graph.run_parallel action_graph build_config.num_jobs;
    Rebuilt
;;
