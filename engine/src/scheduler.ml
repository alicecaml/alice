open! Alice_stdlib
open Alice_hierarchy
open Alice_package
open Alice_error
open Alice_ocaml_compiler
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

  let equal t { output_path; public_interface_to_open } =
    Absolute_path.equal t.output_path output_path
    && Public_interface_to_open.equal t.public_interface_to_open public_interface_to_open
  ;;
end

module Action = struct
  type t =
    | Command of Command.t
    | Generated_public_interface_to_open of Generated_public_interface_to_open.t

  let run_blocking t =
    match t with
    | Command command ->
      let report =
        match Alice_io.Process.Blocking.run_command command with
        | Ok report -> report
        | Error (`Prog_not_available _) ->
          panic [ Pp.textf "Can't find program: %s" command.prog ]
      in
      (match report.status with
       | Exited 0 -> ()
       | _ ->
         Alice_error.user_exn
           [ Pp.textf "Command failed: %s" (Command.to_string_ignore_env command) ])
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

  let equal a b =
    match a, b with
    | Command a, Command b -> Command.equal a b
    | Command _, _ -> false
    | Generated_public_interface_to_open a, Generated_public_interface_to_open b ->
      Generated_public_interface_to_open.equal a b
    | Generated_public_interface_to_open _, _ -> false
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

module Action_graph = struct
  (* This DAG is keyed by [Typed_op] because each action will have a unique
     operation, and knows the operations of their dependencies. *)
  include Alice_dag.Make (Typed_op)

  module Entry = struct
    type t =
      { action : Action.t
      ; package_id : Package_id.t
      ; build_plan : Build_plan.t
      ; remaining_children_to_build : int ref
      }

    let equal t { action; package_id; build_plan; remaining_children_to_build } =
      Action.equal t.action action
      && Package_id.equal t.package_id package_id
      && Build_plan.equal t.build_plan build_plan
      && Int.equal !(t.remaining_children_to_build) !remaining_children_to_build
    ;;
  end

  type nonrec t = Entry.t t

  module Staging = struct
    include Staging

    let add_or_panic t name entry ~child_names =
      add_or_panic t name entry ~eq:Entry.equal ~child_names
    ;;
  end

  let run (t : t) =
    all_nodes_in_child_first_order t
    |> List.iter ~f:(fun node ->
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
        ];
      Action.run_blocking entry.action)
  ;;
end

let make_action_graph
      build_graph
      build_plans
      package_with_deps
      profile
      build_dir
      ocaml_compiler
      ~any_dep_rebuilt
  =
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
        incremental_files_to_build build_plan package_id profile build_dir
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
          let action = op_action op package_with_deps profile build_dir ocaml_compiler in
          let entry =
            { Action_graph.Entry.action
            ; package_id
            ; build_plan
            ; remaining_children_to_build = ref (List.length child_names)
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
    -> Profile.t
    -> Build_dir.t
    -> Ocaml_compiler.t
    -> any_dep_rebuilt:bool
    -> Package_built.t
  =
  fun build_graph package_with_deps profile build_dir ocaml_compiler ~any_dep_rebuilt ->
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
      profile
      build_dir
      ocaml_compiler
      ~any_dep_rebuilt
  with
  | None -> Package_built.Not_rebuilt
  | Some action_graph ->
    println
      (verb_message
         `Compiling
         (Package_id.name_v_version_string (Package_with_deps.id package_with_deps)));
    let package_id = Dependency_graph.Package_with_deps.package_id package_with_deps in
    Build_dir.package_dirs build_dir package_id profile |> List.iter ~f:File_ops.mkdir_p;
    Action_graph.run action_graph;
    Rebuilt
;;
