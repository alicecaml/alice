open! Alice_stdlib
open Alice_package
open Alice_hierarchy
open Alice_error
module File_ops = Alice_io.File_ops

type t =
  { root : Path.Absolute.t
  ; package : Package.t
  }

let of_package package =
  let root = Package.root package in
  { root; package }
;;

let build_dir_path_relative_to_project_root = Path.relative "build"
let build_dir_path { root; _ } = root / build_dir_path_relative_to_project_root

let package_build_dir_path t profile package =
  build_dir_path t
  / Path.relative (Profile.name profile)
  / Path.relative "packages"
  / Path.relative (Package.id package |> Package_id.name_dash_version_string)
;;

let build_single_package_typed t profile package_typed =
  let package = Package.Typed.package package_typed in
  let out_dir = package_build_dir_path t profile package in
  Build_plan.Package_build_planner.create profile package_typed ~out_dir
  |> Build_plan.Package_build_planner.all_plans
  |> List.iter ~f:(fun build_plan ->
    Scheduler.Sequential.eval_build_plan build_plan package ~out_dir)
;;

let build_dependency_graph t profile dependency_graph =
  let open Dependency_graph in
  let rec build_deps nodes = List.iter nodes ~f:build_node
  and build_node node =
    let deps = Traverse_dependencies.deps node in
    build_deps deps;
    let pt = Traverse_dependencies.package_typed node in
    build_single_package_typed t profile pt
  in
  traverse_dependencies dependency_graph |> build_deps;
  build_single_package_typed t profile (root dependency_graph)
;;

let build_package_typed t profile package_typed =
  let dependency_graph = Dependency_graph.compute package_typed in
  build_dependency_graph t profile dependency_graph
;;

let build_package t profile package =
  Package.with_typed
    { f = (fun package_typed -> build_package_typed t profile package_typed) }
    package
;;

let build t profile = build_package t profile t.package

let run t profile ~args =
  let open Alice_ui in
  let package_typed =
    match Package.typed t.package with
    | `Lib_only _ -> user_exn [ Pp.text "Cannot run project as it lacks an executable." ]
    | `Exe_only pt -> pt
    | `Exe_and_lib pt -> Package.Typed.limit_to_exe_only pt
  in
  build_package_typed t profile package_typed;
  let exe_name =
    let exe_name = Package.name t.package |> Package_name.to_string |> Path.relative in
    if Sys.win32 then Path.add_extension exe_name ~ext:".exe" else exe_name
  in
  let out_dir = package_build_dir_path t profile t.package in
  let exe_path = out_dir / exe_name in
  let args = Path.to_filename exe_name :: args in
  let exe_filename = Path.to_filename exe_path in
  println (verb_message `Running (path_to_string exe_path));
  print_newline ();
  match Alice_io.Process.Blocking.run exe_filename ~args with
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
  println (verb_message `Removing (Alice_ui.path_to_string (build_dir_path t)));
  File_ops.rm_rf (build_dir_path t)
;;

let dot_package_build_artifacts t package =
  let profile = Profile.debug in
  Package.with_typed
    { f =
        (fun pt ->
          Build_plan.Package_build_planner.create
            profile
            pt
            ~out_dir:(package_build_dir_path t profile package)
          |> Build_plan.Package_build_planner.dot)
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
