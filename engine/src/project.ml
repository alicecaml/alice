open! Alice_stdlib
open Alice_package
open Alice_hierarchy
open Alice_error
module File_ops = Alice_io.File_ops

type t =
  { build_dir : Build_dir.t
  ; package : Package.t
  }

let build_dir_path_relative_to_project_root = Path.relative "build"

let of_package package =
  let root = Package.root package in
  let build_dir = Build_dir.of_path (root / build_dir_path_relative_to_project_root) in
  { build_dir; package }
;;

let build_single_package_typed
  : type exe lib. t -> (exe, lib) Package.Typed.t -> Profile.t -> unit
  =
  fun t package_typed profile ->
  let package = Package.Typed.package package_typed in
  let build_graph = Build_graph.create package_typed t.build_dir in
  match Package.Typed.type_ package_typed with
  | Exe_only ->
    let build_plan = Build_graph.plan_exe build_graph in
    Scheduler.Sequential.eval_build_plan build_plan package profile t.build_dir
  | Lib_only -> ()
  | Exe_and_lib -> ()
;;

let build_dependency_graph t dependency_graph profile =
  let open Dependency_graph in
  let rec build_deps nodes = List.iter nodes ~f:build_node
  and build_node node =
    let deps = Traverse_dependencies.deps node in
    build_deps deps;
    let pt = Traverse_dependencies.package_typed node in
    build_single_package_typed t pt profile
  in
  traverse_dependencies dependency_graph |> build_deps;
  build_single_package_typed t (root dependency_graph) profile
;;

let build_package_typed t package_typed profile =
  let dependency_graph = Dependency_graph.compute package_typed in
  build_dependency_graph t dependency_graph profile
;;

let build_package t package profile =
  Package.with_typed
    { f = (fun package_typed -> build_package_typed t package_typed profile) }
    package
;;

let build t profile = build_package t t.package profile

let run t profile ~args =
  let open Alice_ui in
  let package_typed =
    match Package.typed t.package with
    | `Lib_only _ -> user_exn [ Pp.text "Cannot run project as it lacks an executable." ]
    | `Exe_only pt -> pt
    | `Exe_and_lib pt -> Package.Typed.limit_to_exe_only pt
  in
  build_package_typed t package_typed profile;
  let exe_name =
    let exe_name = Package.name t.package |> Package_name.to_string |> Path.relative in
    if Sys.win32 then Path.add_extension exe_name ~ext:".exe" else exe_name
  in
  let exe_path = Build_dir.package_exe_dir t.build_dir (Package.id t.package) profile in
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
  let to_remove = Build_dir.path t.build_dir in
  println (verb_message `Removing (Alice_ui.path_to_string to_remove));
  File_ops.rm_rf to_remove
;;

let dot_package_build_artifacts t package =
  Package.with_typed
    { f = (fun pt -> Build_graph.create pt t.build_dir |> Build_graph.dot) }
    package
;;

let dot_package_dependencies package =
  Package.with_typed
    { f = (fun pt -> Dependency_graph.dot (Dependency_graph.compute pt)) }
    package
;;

let dot_build_artifacts t = dot_package_build_artifacts t t.package
let dot_dependencies t = dot_package_dependencies t.package
