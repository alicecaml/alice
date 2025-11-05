open! Alice_stdlib
open Alice_package
open Alice_hierarchy
open Alice_error
module File_ops = Alice_io.File_ops
module Package_with_deps = Dependency_graph.Package_with_deps

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

let build_single_package
  : type exe lib.
    t
    -> (exe, lib) Package_with_deps.t
    -> Profile.t
    -> Alice_env.Os_type.t
    -> Alice_env.Env.t
    -> Alice_which.Ocaml_compiler.t
    -> unit
  =
  fun t package_with_deps profile os_type env ocaml_compiler ->
  let package_typed = Package_with_deps.package_typed package_with_deps in
  let build_graph =
    Build_graph.create package_typed t.build_dir os_type env ocaml_compiler
  in
  let build_plans =
    match Package.Typed.type_ package_typed with
    | Exe_only -> [ Build_graph.plan_exe build_graph ]
    | Lib_only -> [ Build_graph.plan_lib build_graph ]
    | Exe_and_lib ->
      [ Build_graph.plan_lib build_graph; Build_graph.plan_exe build_graph ]
  in
  Scheduler.Sequential.eval_build_plans
    build_plans
    package_with_deps
    env
    profile
    t.build_dir
    ocaml_compiler
;;

let build_dependency_graph t dependency_graph profile os_type env ocaml_compiler =
  let open Dependency_graph in
  transitive_dependency_closure_in_dependency_order dependency_graph
  |> List.iter ~f:(fun package_with_deps ->
    build_single_package t package_with_deps profile os_type env ocaml_compiler);
  let root = root_package_with_deps dependency_graph in
  build_single_package t root profile os_type env ocaml_compiler
;;

let build_package_typed t package_typed profile env ocaml_compiler =
  let dependency_graph = Dependency_graph.compute package_typed in
  build_dependency_graph t dependency_graph profile env ocaml_compiler
;;

let build_package t package profile env ocaml_compiler =
  Package.with_typed
    { f =
        (fun package_typed ->
          build_package_typed t package_typed profile env ocaml_compiler)
    }
    package
;;

let build t profile os_type env ocaml_compiler =
  let open Alice_ui in
  build_package t t.package profile os_type env ocaml_compiler;
  println
    (verb_message
       `Finished
       (sprintf
          "%s build of package: '%s'"
          (Profile.name profile)
          (Package_id.name_v_version_string (Package.id t.package))))
;;

let run t profile os_type env ocaml_compiler ~args =
  let open Alice_ui in
  let package_typed =
    match Package.typed t.package with
    | `Lib_only _ -> user_exn [ Pp.text "Cannot run project as it lacks an executable." ]
    | `Exe_only pt -> pt
    | `Exe_and_lib pt -> Package.Typed.limit_to_exe_only pt
  in
  build_package_typed t package_typed profile os_type env ocaml_compiler;
  let exe_name =
    Package.name t.package
    |> Package_name.to_string
    |> Basename.of_filename
    |> Alice_env.Os_type.basename_add_exe_extension_on_windows os_type
  in
  let exe_path =
    Build_dir.package_executable_dir t.build_dir (Package.id t.package) profile / exe_name
  in
  let args = Basename.to_filename exe_name :: args in
  let exe_filename = Absolute_path.to_filename exe_path in
  println (verb_message `Running (absolute_path_to_string exe_path));
  print_newline ();
  match Alice_io.Process.Blocking.run exe_filename ~args ~env with
  | Error `Prog_not_available ->
    panic
      [ Pp.textf
          "The executable %s does not exist. Alice was supposed to create that file. \
           This is a bug in Alice."
          exe_filename
      ]
  | Ok (Exited code) -> exit code
  | Ok (Signaled signal | Stopped signal) ->
    println
      (raw_message
         (sprintf "The executable %s was stopped by a signal (%d)." exe_filename signal));
    exit 0
;;

let clean t =
  let open Alice_ui in
  let to_remove = Build_dir.path t.build_dir in
  println (verb_message `Removing (Alice_ui.absolute_path_to_string to_remove));
  File_ops.rm_rf to_remove
;;

let dot_package_build_artifacts t package os_type env ocaml_compiler =
  Package.with_typed
    { f =
        (fun pt ->
          Build_graph.create pt t.build_dir os_type env ocaml_compiler |> Build_graph.dot)
    }
    package
;;

let dot_package_dependencies package =
  Package.with_typed
    { f = (fun pt -> Dependency_graph.dot (Dependency_graph.compute pt)) }
    package
;;

let dot_build_artifacts t = dot_package_build_artifacts t t.package
let dot_dependencies t = dot_package_dependencies t.package
