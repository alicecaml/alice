open! Alice_stdlib
open Alice_package_meta
open Alice_error
open Alice_hierarchy
module Builtin_module = Alice_builtin_module
module Dag = Alice_dag.Make (Package_name)

type nonrec t =
  { dag : Package.Typed.lib_only_t Dag.t
  ; all_nodes_in_dependency_order : Package.Typed.lib_only_t Dag.Node.t list
  }

let to_dyn { dag; all_nodes_in_dependency_order } =
  Dyn.record
    [ "dag", Dag.to_dyn Package.Typed.to_dyn dag
    ; ( "all_nodes_in_dependency_order"
      , Dyn.list (Dag.Node.to_dyn Package.Typed.to_dyn) all_nodes_in_dependency_order )
    ]
;;

module Staging = struct
  include Dag.Staging

  let add_package_typed t package_typed =
    let name = Package.name (Package.Typed.package package_typed) in
    let child_names =
      Package.Typed.package package_typed |> Package.dependencies |> Dependencies.names
    in
    add_or_panic t name package_typed ~eq:Package.Typed.equal ~child_names
  ;;

  let finalize t =
    let dag =
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
    in
    let all_nodes_in_dependency_order = Dag.all_nodes_in_child_first_order dag in
    { dag; all_nodes_in_dependency_order }
  ;;
end

(* Given a package and one of its dependencies, resolve the dependency to the
   package it refers to. *)
let load_dependency package dep =
  match Dependency.source dep with
  | Local_directory dir_path ->
    let dep_root =
      match dir_path with
      | `Absolute root -> root
      | `Relative rel_root ->
        Absolute_path.Root_or_non_root.concat_relative_exn (Package.root package) rel_root
    in
    let package = Package.read_root dep_root in
    (match Package_name.equal (Dependency.name dep) (Package.name package) with
     | true -> package
     | false ->
       user_exn
         [ Pp.textf
             "The package loaded from %S was expected to be named %S, but got %S instead."
             (Either_path.to_filename dir_path)
             (Dependency.name dep |> Package_name.to_string)
             (Package.name package |> Package_name.to_string)
         ])
;;

(* Ensures a given dependency package contains a library, and returns a typed
   package that statically ensures that the package has a library. *)
let package_to_non_exe_typed_package ~root_package dep_package =
  match Package.typed dep_package with
  | `Exe_only _ ->
    user_exn
      [ Pp.textf
          "The package %S does not contain a library, but is a transitive dependency of \
           %S."
          (Package.id dep_package |> Package_id.name_v_version_string)
          (Package.id root_package |> Package_id.name_v_version_string)
      ]
  | `Lib_only pt -> pt
  | `Exe_and_lib pt -> Package.Typed.limit_to_lib_only pt
;;

(* Returns a list of packages reachable through an initial list of dependency
   packages. The root package should not be in the initial list of
   dependencies. *)
let transitive_dependency_closure ~root_package initial_deps =
  let rec loop seen to_expand =
    match to_expand with
    | [] -> seen
    | x :: xs ->
      let unseen_x_dep_packages =
        Package.dependencies x
        |> Dependencies.to_list
        |> List.filter_map ~f:(fun dep ->
          let package = load_dependency x dep in
          if Package_id.Map.mem (Package.id package) seen then None else Some package)
      in
      let seen =
        Package_id.Map.add_seq
          (List.to_seq unseen_x_dep_packages
           |> Seq.map ~f:(fun package -> Package.id package, package))
          seen
      in
      let to_expand = unseen_x_dep_packages @ xs in
      loop seen to_expand
  in
  let seen =
    List.map initial_deps ~f:(fun package ->
      let package_id = Package.id package in
      if Package_id.equal package_id (Package.id root_package)
      then
        panic
          [ Pp.textf
              "Root package %S was listed as one of its initial dependencies"
              (Package_id.name_v_version_string package_id)
          ];
      package_id, package)
    |> Package_id.Map.of_list_exn
  in
  Package_id.Map.values (loop seen initial_deps)
  |> List.map ~f:(package_to_non_exe_typed_package ~root_package)
;;

let transitive_dependency_closure_regular_deps root_package =
  let deps =
    Package.dependencies root_package
    |> Dependencies.to_list
    |> List.map ~f:(load_dependency root_package)
  in
  transitive_dependency_closure ~root_package deps
;;

let transitive_dependency_closure_config_script_deps root_package =
  let deps =
    Package.meta root_package
    |> Package_meta.config_script
    |> Package_meta.Config_script_meta.dependencies
    |> Dependencies.to_list
    |> List.map ~f:(load_dependency root_package)
  in
  transitive_dependency_closure ~root_package deps
;;

let of_closure closure =
  let staging = List.fold_left closure ~init:Staging.empty ~f:Staging.add_package_typed in
  Staging.finalize staging
;;

let compute ~dep_type package =
  let closure =
    match dep_type with
    | `Regular -> transitive_dependency_closure_regular_deps package
    | `Config_script -> transitive_dependency_closure_config_script_deps package
  in
  of_closure closure
;;

let of_package_config_script_deps package = compute ~dep_type:`Config_script package

module Package_with_deps = struct
  type nonrec ('exe, 'lib) t =
    { package_typed : ('exe, 'lib) Package.Typed.t
    ; dependency_dag : t
    ; is_root : bool
    }

  type lib_only_t = (Type_bool.false_t, Type_bool.true_t) t

  let of_package_typed package_typed =
    let dependency_dag =
      compute ~dep_type:`Regular (Package.Typed.package package_typed)
    in
    { package_typed; dependency_dag; is_root = true }
  ;;

  let dependency_graph { dependency_dag; _ } = dependency_dag
  let package_typed { package_typed; _ } = package_typed
  let package t = package_typed t |> Package.Typed.package
  let package_id t = package t |> Package.id
  let type_ t = package_typed t |> Package.Typed.type_
  let name t = package t |> Package.name
  let id t = package t |> Package.id
  let builtin_modules t = package t |> Package.builtin_modules

  let immediate_deps_in_dependency_order t =
    let immediate_dep_names =
      package t |> Package.dependency_names |> Package_name.Set.of_list
    in
    List.filter_map t.dependency_dag.all_nodes_in_dependency_order ~f:(fun node ->
      if Package_name.Set.mem (Dag.Node.name node) immediate_dep_names
      then (
        let package_typed = Dag.Node.value node in
        Some { package_typed; dependency_dag = t.dependency_dag; is_root = false })
      else None)
  ;;

  let transitive_dependency_closure_excluding_package
        { package_typed; dependency_dag; is_root }
    =
    let nodes =
      if is_root
      then dependency_dag.all_nodes_in_dependency_order
      else (
        let start =
          Dag.get_node dependency_dag.dag ~name:(Package.Typed.name package_typed)
        in
        Dag.Node.transitive_closure_in_child_first_order start ~include_start:false)
    in
    List.map nodes ~f:Dag.Node.value
  ;;

  let to_string_graph t =
    let node_to_string node =
      Dag.Node.value node |> Package.Typed.id |> Package_id.name_v_version_string
    in
    Dag.to_string_graph t.dependency_dag.dag ~node_to_string
    |> String.Map.add
         ~key:
           (Package_id.name_v_version_string
              (Package.id (Package.Typed.package t.package_typed)))
         ~data:
           (Dag.roots t.dependency_dag.dag
            |> Seq.map ~f:node_to_string
            |> String.Set.of_seq)
  ;;

  let dot t = to_string_graph t |> Alice_graphviz.dot_src_of_string_graph
end

let transitive_dependency_closure_in_dependency_order t =
  List.map t.all_nodes_in_dependency_order ~f:(fun node ->
    let package_typed = Dag.Node.value node in
    { Package_with_deps.package_typed; is_root = false; dependency_dag = t })
;;

let roots t =
  Dag.roots t.dag
  |> Seq.map ~f:(fun node ->
    let package_typed = Dag.Node.value node in
    { Package_with_deps.package_typed; is_root = false; dependency_dag = t })
  |> List.of_seq
;;
