open! Alice_stdlib
open Alice_package_meta
open Alice_error
open Alice_hierarchy

module Node = struct
  type t = Package.Typed.lib_only_t

  module Name = Package_name

  let to_dyn = Package.Typed.to_dyn
  let equal = Package.Typed.equal
  let name t = Package.Typed.package t |> Package.name

  let dep_names t =
    Package.Typed.package t
    |> Package.dependencies
    |> Dependencies.names
    |> Package_name.Set.of_list
  ;;

  let show t = Package.Typed.package t |> Package.id |> Package_id.name_v_version_string
end

module Dependency_dag = struct
  include Alice_dag.Make (Node)

  module Staging = struct
    include Staging

    let add_package_typed t package_typed =
      let name = Package.name (Package.Typed.package package_typed) in
      match add t name package_typed with
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
end

let transitive_dependency_closure package =
  let rec loop acc package =
    let deps = Package.dependencies package |> Dependencies.to_list in
    let dep_packages =
      List.map deps ~f:(fun dep ->
        match Dependency.source dep with
        | Local_directory dir_path ->
          let dep_root =
            match dir_path with
            | `Absolute root -> root
            | `Relative rel_root ->
              `Non_root
                (Absolute_path.Root_or_non_root.concat_relative
                   (Package.root package)
                   rel_root)
          in
          Package.read_root dep_root)
    in
    List.fold_left dep_packages ~init:acc ~f:(fun acc dep_package ->
      let dep_package_lib =
        match Package.typed dep_package with
        | `Exe_only _ ->
          user_exn
            [ Pp.textf
                "The package %S does not contain a library, but is a transitive \
                 dependency of %S."
                (Package.id dep_package |> Package_id.name_v_version_string)
                (Package.id package |> Package_id.name_v_version_string)
            ]
        | `Lib_only pt -> pt
        | `Exe_and_lib pt -> Package.Typed.limit_to_lib_only pt
      in
      let acc = dep_package_lib :: acc in
      loop acc dep_package)
  in
  loop [] package
;;

type ('exe, 'lib) t =
  { root : ('exe, 'lib) Package.Typed.t
  ; dependency_dag : Dependency_dag.t
  }

let to_dyn { root; dependency_dag } =
  Dyn.record
    [ "root", Package.Typed.to_dyn root
    ; "dependency_dag", Dependency_dag.to_dyn dependency_dag
    ]
;;

let compute package_typed =
  let closure = transitive_dependency_closure (Package.Typed.package package_typed) in
  let staging =
    List.fold_left
      closure
      ~init:Dependency_dag.Staging.empty
      ~f:Dependency_dag.Staging.add_package_typed
  in
  let dependency_dag = Dependency_dag.Staging.finalize staging in
  { root = package_typed; dependency_dag }
;;

let to_string_graph t =
  Dependency_dag.to_string_graph t.dependency_dag
  |> String.Map.add
       ~key:(Package_id.name_v_version_string (Package.id (Package.Typed.package t.root)))
       ~data:
         (Dependency_dag.roots t.dependency_dag
          |> List.map ~f:Node.show
          |> String.Set.of_list)
;;

let dot t = to_string_graph t |> Alice_graphviz.dot_src_of_string_graph

module Package_with_deps = struct
  type ('exe, 'lib) t =
    { package_typed : ('exe, 'lib) Package.Typed.t
    ; immediate_deps : Package.Typed.lib_only_t list
    }

  let package_typed { package_typed; _ } = package_typed
  let package t = package_typed t |> Package.Typed.package
  let immediate_deps { immediate_deps; _ } = immediate_deps
end

let root_package_with_deps { root; dependency_dag } =
  let immediate_deps = Dependency_dag.roots dependency_dag in
  { Package_with_deps.package_typed = root; immediate_deps }
;;

let transitive_dependency_closure_in_dependency_order { dependency_dag; _ } =
  Dependency_dag.all_nodes_in_dependency_order dependency_dag
  |> List.map ~f:(fun package_typed ->
    let traverse =
      Dependency_dag.traverse dependency_dag ~name:(Node.name package_typed)
    in
    let immediate_deps =
      Dependency_dag.Traverse.deps traverse |> List.map ~f:Dependency_dag.Traverse.node
    in
    { Package_with_deps.package_typed; immediate_deps })
;;
