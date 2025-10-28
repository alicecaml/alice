open! Alice_stdlib
open Alice_package_meta
open Alice_hierarchy

module Node = struct
  include Package
  module Name = Package_name

  let dep_names t = dependencies t |> Dependencies.names |> Package_name.Set.of_list
  let show t = id t |> Package_id.name_v_version_string
end

include Alice_dag.Make (Node)

module Traverse = struct
  include Traverse

  let package = node
end

let traverse t ~package_name = traverse t ~name:package_name

module Staging = struct
  include Staging

  let add_package t package =
    let name = Package.name package in
    match add t name package with
    | Ok t -> t
    | Error (`Conflict _) ->
      Alice_error.panic
        [ Pp.textf "Conflicting packages with name: %s" (Package_name.to_string name) ]
  ;;

  let finalize t =
    match finalize t with
    | Ok t -> t
    | Error (`Dangling dangling) ->
      Alice_error.panic
        [ Pp.textf "No package with name: %s" (Package_name.to_string dangling) ]
    | Error (`Cycle cycle) ->
      Alice_error.panic
        ([ Pp.text "Dependency cycle:"; Pp.newline ]
         @ List.concat_map cycle ~f:(fun file ->
           [ Pp.textf " - %s" (Package_name.to_string file); Pp.newline ]))
  ;;
end

let transitive_dependency_closure package =
  let rec loop acc package =
    let acc = package :: acc in
    let deps = Package.dependencies package |> Dependencies.to_list in
    let dep_packages =
      List.map deps ~f:(fun dep ->
        match Dependency.source dep with
        | Local_directory dir_path ->
          let dep_root =
            match dir_path with
            | `Absolute root -> root
            | `Relative rel_root -> Path.concat (Package.root package) rel_root
          in
          Package.read_root dep_root)
    in
    List.fold_left dep_packages ~init:acc ~f:loop
  in
  loop [] package
;;

let compute package =
  let closure = transitive_dependency_closure package in
  let staging = List.fold_left closure ~init:Staging.empty ~f:Staging.add_package in
  Staging.finalize staging
;;
