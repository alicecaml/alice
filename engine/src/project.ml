open! Alice_stdlib
open Alice_package
open Alice_hierarchy
open Alice_error
module File_ops = Alice_io.File_ops
module Package_with_deps = Dependency_graph.Package_with_deps
module Io_ctx = Alice_io.Io_ctx
open Alice_ocaml_compiler

type t =
  { build_dir : Build_dir.t
  ; package : Package.t
  }

let build_dir_path_relative_to_project_root = Basename.of_filename "build"

let of_package package =
  let root = Package.root package in
  let build_dir =
    Build_dir.of_path
      (Absolute_path.Root_or_non_root.concat_basename
         root
         build_dir_path_relative_to_project_root)
  in
  { build_dir; package }
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

let write_dot_merlin t root_package_with_deps profile ~ocamllib_path =
  let text =
    Dot_merlin.dot_merlin_text root_package_with_deps t.build_dir profile ~ocamllib_path
  in
  File_ops.write_text_file (dot_merlin_path t) text
;;

module Dot_gitignore = struct
  let path root =
    Absolute_path.Root_or_non_root.concat_basename
      root
      (Basename.of_filename ".gitignore")
  ;;

  let text () =
    let files = [ build_dir_path_relative_to_project_root; Dot_merlin.basename ] in
    List.map files ~f:Basename.to_filename |> String.concat ~sep:"\n"
  ;;

  let write root = File_ops.write_text_file (path root) (text ())
end

let write_dot_gitignore { package; _ } = Dot_gitignore.write (Package.root package)

let build_single_package
  : type exe lib.
    t
    -> _ Io_ctx.t
    -> (exe, lib) Package_with_deps.t
    -> Profile.t
    -> Alice_env.Os_type.t
    -> Ocaml_compiler.t
    -> any_dep_rebuilt:bool
    -> Scheduler.Package_built.t
  =
  fun t io_ctx package_with_deps profile os_type ocaml_compiler ~any_dep_rebuilt ->
  let package_typed = Package_with_deps.package_typed package_with_deps in
  let build_graph =
    Build_graph.create package_typed t.build_dir os_type ocaml_compiler io_ctx
  in
  let build_plans =
    match Package.Typed.type_ package_typed with
    | Exe_only -> [ Build_graph.plan_exe build_graph ]
    | Lib_only -> [ Build_graph.plan_lib build_graph; Build_graph.plan_lsp build_graph ]
    | Exe_and_lib ->
      [ Build_graph.plan_lib build_graph
      ; Build_graph.plan_lsp build_graph
      ; Build_graph.plan_exe build_graph
      ]
  in
  Scheduler.eval_build_plans
    io_ctx
    build_plans
    package_with_deps
    profile
    t.build_dir
    ocaml_compiler
    ~any_dep_rebuilt
;;

let build_dependency_graph t io_ctx dependency_graph profile os_type ocaml_compiler =
  let build_single_package package_with_deps ~any_dep_rebuilt =
    build_single_package
      t
      io_ctx
      package_with_deps
      profile
      os_type
      ocaml_compiler
      ~any_dep_rebuilt
  in
  let rec build_package_building_deps_first
    : type exe lib.
      (exe, lib) Package_with_deps.t
      -> already_built_packages:Scheduler.Package_built.t Package_id.Map.t
      -> Scheduler.Package_built.t * Scheduler.Package_built.t Package_id.Map.t
    =
    fun package_with_deps ~already_built_packages ->
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
  let _root_package_built : Scheduler.Package_built.t =
    build_package_building_deps_first
      (Dependency_graph.root_package_with_deps dependency_graph)
      ~already_built_packages:Package_id.Map.empty
    |> fst
  in
  ()
;;

let build_package_typed
      t
      (io_ctx : _ Io_ctx.t)
      package_typed
      profile
      os_type
      ocaml_compiler
  =
  let dependency_graph = Dependency_graph.compute package_typed in
  let ocamllib_path = Ocaml_compiler.standard_library ocaml_compiler io_ctx in
  write_dot_merlin
    t
    (Dependency_graph.root_package_with_deps dependency_graph)
    profile
    ~ocamllib_path;
  build_dependency_graph t io_ctx dependency_graph profile os_type ocaml_compiler
;;

let build_package t io_ctx package profile ocaml_compiler =
  Package.with_typed
    { f =
        (fun package_typed ->
          build_package_typed t io_ctx package_typed profile ocaml_compiler)
    }
    package
;;

let build t io_ctx profile os_type ocaml_compiler =
  let open Alice_ui in
  build_package t io_ctx t.package profile os_type ocaml_compiler;
  println
    (verb_message
       `Finished
       (sprintf
          "%s build of package: '%s'"
          (Profile.name profile)
          (Package_id.name_v_version_string (Package.id t.package))))
;;

let run t (io_ctx : _ Io_ctx.t) profile os_type ocaml_compiler ~args =
  let open Alice_ui in
  let package_typed =
    match Package.typed t.package with
    | `Lib_only _ -> user_exn [ Pp.text "Cannot run project as it lacks an executable." ]
    | `Exe_only pt -> pt
    | `Exe_and_lib pt -> Package.Typed.limit_to_exe_only pt
  in
  build_package_typed t io_ctx package_typed profile os_type ocaml_compiler;
  let exe_name =
    Package.name t.package
    |> Package_name.to_string
    |> Basename.of_filename
    |> Alice_env.Os_type.basename_add_exe_extension_on_windows os_type
  in
  let exe_path =
    Build_dir.package_executable_dir t.build_dir (Package.id t.package) profile / exe_name
  in
  let exe_filename = Absolute_path.to_filename exe_path in
  println (verb_message `Running (absolute_path_to_string exe_path));
  print_newline ();
  match
    Alice_io.Process.Eio.run
      io_ctx
      exe_filename
      ~args
      ~env:(Ocaml_compiler.env ocaml_compiler)
  with
  | Error (`Program_not_available _) ->
    panic
      [ Pp.textf
          "The executable %s does not exist. Alice was supposed to create that file. \
           This is a bug in Alice."
          exe_filename
      ]
  | Error (`Generic_error message) -> Printf.eprintf "%s" message
  | Ok () -> ()
;;

let clean t =
  let open Alice_ui in
  let to_remove = Build_dir.path t.build_dir in
  println (verb_message `Removing (Alice_ui.absolute_path_to_string to_remove));
  File_ops.rm_rf to_remove
;;

let dot_package_build_artifacts t (io_ctx : _ Io_ctx.t) package os_type ocaml_compiler =
  Package.with_typed
    { f =
        (fun pt ->
          Build_graph.create pt t.build_dir os_type ocaml_compiler io_ctx
          |> Build_graph.dot)
    }
    package
;;

let dot_package_dependencies package =
  Package.with_typed
    { f = (fun pt -> Dependency_graph.dot (Dependency_graph.compute pt)) }
    package
;;

let dot_build_artifacts t io_ctx = dot_package_build_artifacts t io_ctx t.package
let dot_dependencies t = dot_package_dependencies t.package
