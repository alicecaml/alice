open! Alice_stdlib
open Alice_package
open Alice_hierarchy
module Dependency_graph = Alice_engine.Dependency_graph

let transitive_dependency_closure package =
  let rec loop acc package =
    let acc = package :: acc in
    let deps = Package.dependencies package |> Dependencies.to_list in
    let dep_packages =
      List.map deps ~f:(fun dep ->
        match Dependency.source dep with
        | Local_directory dir_path ->
          Path.Either.with_
            dir_path
            ~with_path:{ f = (fun dir_path -> Alice_manifest.read_package_dir ~dir_path) })
    in
    List.fold_left dep_packages ~init:acc ~f:loop
  in
  loop [] package
;;

let resolve package =
  let closure = transitive_dependency_closure package in
  let staging =
    List.fold_left
      closure
      ~init:Dependency_graph.Staging.empty
      ~f:Dependency_graph.Staging.add_package
  in
  Dependency_graph.Staging.finalize staging
;;
