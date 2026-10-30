open! Alice_stdlib
open Alice_package
open Alice_hierarchy
open Alice_error
module File_ops = Alice_io.File_ops
module Package_with_deps = Dependency_graph.Package_with_deps
module Package_base_dir = Build_dir.Package_base_dir
open Alice_ocaml_toolchain

type t =
  { build_dir : Build_dir.t
  ; package : Package.t
  }

let of_package package =
  let root = Package.root package in
  let build_dir = Build_dir.of_project_root_path root in
  { build_dir; package }
;;

let package_base_dir_of_build_config t build_config =
  Build_dir.package_base_dir_of_build_config
    t.build_dir
    (Package.id t.package)
    build_config
;;

let dot_merlin_path { package; _ } =
  Absolute_path.Root_or_non_root.concat_basename
    (Package.root package)
    Dot_merlin.basename
;;

let write_dot_merlin_initial t =
  let text = Dot_merlin.dot_merlin_text_initial () in
  File_ops.write_text_file (dot_merlin_path t) text
;;

let write_dot_merlin t root_package_with_deps build_config =
  let text = Dot_merlin.dot_merlin_text root_package_with_deps t.build_dir build_config in
  File_ops.write_text_file (dot_merlin_path t) text
;;

module Dot_gitignore = struct
  let path root =
    Absolute_path.Root_or_non_root.concat_basename
      root
      (Basename.of_filename ".gitignore")
  ;;

  let text () =
    let files = [ Build_dir.basename; Dot_merlin.basename ] in
    List.map files ~f:Basename.to_filename |> String.concat ~sep:"\n"
  ;;

  let write root = File_ops.write_text_file (path root) (text ())
end

let write_dot_gitignore { package; _ } = Dot_gitignore.write (Package.root package)

let rec run_config_script t package build_config ~built_artifacts_from_deps =
  match Package.config_script_path package with
  | None -> ()
  | Some config_script_source_path ->
    let build_config : Build_config.t =
      { build_config with profile = Profile.minimal; compiler_backend = Bytecode }
    in
    let config_script_dependency_graph =
      Dependency_graph.of_package_config_script_deps package
    in
    let any_dep_rebuilt =
      build_dependency_graph
        t
        config_script_dependency_graph
        build_config
        ~built_artifacts_from_deps
    in
    Config_script.run
      t.build_dir
      build_config
      (Package.meta package)
      ~config_script_dependency_graph
      ~config_script_source_path
      ~any_dep_rebuilt

(* Build a package, assuming all of its dependencies have already been built. *)
and build_single_package
  : type exe lib.
    t
    -> (exe, lib) Package_with_deps.t
    -> Build_config.t
    -> any_dep_rebuilt:bool
    -> built_artifacts_from_deps:bool
    -> Scheduler.Package_built.t
  =
  fun t package_with_deps build_config ~any_dep_rebuilt ~built_artifacts_from_deps ->
  let package_typed = Package_with_deps.package_typed package_with_deps in
  let package = Package.Typed.package package_typed in
  let build_graph = Build_graph.create package_typed t.build_dir build_config in
  let package_base_dir =
    Build_dir.package_base_dir_of_build_config
      t.build_dir
      (Package_with_deps.id package_with_deps)
      build_config
  in
  let () = run_config_script t package build_config ~built_artifacts_from_deps in
  Scheduler.run
    build_graph
    package_with_deps
    package_base_dir
    build_config
    ~any_dep_rebuilt
    ~built_artifacts_from_deps

(* Returns true if any package was actually built. *)
and build_dependency_graph t dependency_graph build_config ~built_artifacts_from_deps =
  let build_single_package package_with_deps ~any_dep_rebuilt =
    build_single_package
      t
      package_with_deps
      build_config
      ~any_dep_rebuilt
      ~built_artifacts_from_deps
  in
  let rec build_package_building_deps_first package_with_deps ~already_built_packages =
    let package_id = Package_with_deps.id package_with_deps in
    match Package_id.Map.find_opt package_id already_built_packages with
    | Some package_built -> package_built, already_built_packages
    | None ->
      let deps = Package_with_deps.immediate_deps_in_dependency_order package_with_deps in
      let deps_built, already_built_packages =
        List.fold_left
          deps
          ~init:([], already_built_packages)
          ~f:(fun (deps_built, already_built_packages) dep ->
            let dep_built, already_built_packages =
              build_package_building_deps_first dep ~already_built_packages
            in
            dep_built :: deps_built, already_built_packages)
      in
      let package_built =
        build_single_package
          package_with_deps
          ~any_dep_rebuilt:(Scheduler.Package_built.any_rebuilt deps_built)
      in
      let already_built_packages =
        Package_id.Map.add already_built_packages ~key:package_id ~data:package_built
      in
      package_built, already_built_packages
  in
  List.fold_left
    (Dependency_graph.roots dependency_graph)
    ~init:([], Package_id.Map.empty)
    ~f:(fun (packages_built, already_built_packages) root ->
      let package_built, already_built_packages =
        build_package_building_deps_first root ~already_built_packages
      in
      package_built :: packages_built, already_built_packages)
  |> fst
  |> Scheduler.Package_built.any_rebuilt
;;

let build_package_with_deps
      t
      root_package_with_deps
      build_config
      ~built_artifacts_from_deps
  =
  let build_single_package package_with_deps ~any_dep_rebuilt =
    build_single_package
      t
      package_with_deps
      build_config
      ~any_dep_rebuilt
      ~built_artifacts_from_deps
  in
  let _root_package_built : Scheduler.Package_built.t =
    if built_artifacts_from_deps
    then
      (* If using built artifacts from deps, only build the root package. This
         assumes all deps have already been built. This is intended to only be
         used when building multiple interdependent packages such as in a repo
         CI setting. *)
      build_single_package root_package_with_deps ~any_dep_rebuilt:true
    else (
      let any_dep_rebuilt =
        build_dependency_graph
          t
          (Package_with_deps.dependency_graph root_package_with_deps)
          build_config
          ~built_artifacts_from_deps
      in
      build_single_package root_package_with_deps ~any_dep_rebuilt)
  in
  ()
;;

let build_package_typed t package_typed build_config ~built_artifacts_from_deps =
  let package_with_deps = Package_with_deps.of_package_typed package_typed in
  write_dot_merlin t package_with_deps build_config;
  build_package_with_deps t package_with_deps build_config ~built_artifacts_from_deps
;;

let build_package t package build_config ~built_artifacts_from_deps =
  Package.with_typed
    { f =
        (fun package_typed ->
          build_package_typed t package_typed build_config ~built_artifacts_from_deps)
    }
    package
;;

let build t (build_config : Build_config.t) ~built_artifacts_from_deps =
  let open Alice_ui in
  build_package t t.package build_config ~built_artifacts_from_deps;
  println
    (verb_message
       `Finished
       (sprintf
          "%s build of package: '%s'"
          (Profile.name build_config.profile)
          (Package_id.name_v_version_string (Package.id t.package))))
;;

let run t (build_config : Build_config.t) ~args ~built_artifacts_from_deps =
  let open Alice_ui in
  let package_typed =
    match Package.typed t.package with
    | `Lib_only _ -> user_exn [ Pp.text "Cannot run project as it lacks an executable." ]
    | `Exe_only pt -> pt
    | `Exe_and_lib pt -> Package.Typed.limit_to_exe_only pt
  in
  build_package_typed t package_typed build_config ~built_artifacts_from_deps;
  let exe_name =
    Package.name t.package
    |> Package_name.to_string
    |> Basename.of_filename
    |> Alice_env.Os_type.basename_add_exe_extension_on_windows build_config.os_type
  in
  let exe_path =
    (package_base_dir_of_build_config t build_config |> Package_base_dir.executable_dir)
    / exe_name
  in
  let exe_filename = Absolute_path.to_filename exe_path in
  println (verb_message `Running (absolute_path_to_string exe_path));
  print_newline ();
  match
    Alice_io.Process.Blocking.run
      exe_filename
      ~args
      ~env:(Ocaml_toolchain.env build_config.ocaml_toolchain)
  with
  | Error (`Prog_not_available prog) ->
    panic
      [ Pp.textf
          "The executable %S does not exist. Alice was supposed to create that file. \
           This is a bug in Alice."
          prog
      ]
  | Ok (report : Alice_io.Process.Report.t) ->
    (match report.status with
     | Exited code -> exit code
     | Signaled signal | Stopped signal ->
       println
         (raw_message
            (sprintf
               "The executable %s was stopped by a signal (%d)."
               exe_filename
               signal));
       exit 0)
;;

let clean t =
  let open Alice_ui in
  let to_remove = Build_dir.path t.build_dir in
  println (verb_message `Removing (Alice_ui.absolute_path_to_string to_remove));
  File_ops.rm_rf to_remove
;;

let dot_build_artifacts t build_config =
  Package.with_typed
    { f = (fun pt -> Build_graph.create pt t.build_dir build_config |> Build_graph.dot) }
    t.package
;;

let dot_dependencies t =
  Package.with_typed
    { f =
        (fun pt ->
          Dependency_graph.Package_with_deps.dot
            (Dependency_graph.Package_with_deps.of_package_typed pt))
    }
    t.package
;;
