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

  type nonrec t =
    { dag : t
    ; all_nodes_in_dependency_order : Package.Typed.lib_only_t list
    }

  let to_dyn { dag; all_nodes_in_dependency_order } =
    Dyn.record
      [ "dag", to_dyn dag
      ; ( "all_nodes_in_dependency_order"
        , Dyn.list Package.Typed.to_dyn all_nodes_in_dependency_order )
      ]
  ;;

  module Staging = struct
    include Staging

    let add_package_typed t package_typed =
      let name = Package.name (Package.Typed.package package_typed) in
      match add t name package_typed with
      | Ok t -> t
      | Error (`Conflict existing) ->
        Alice_error.panic
          [ Pp.textf "Conflicting packages with name: %s" (Package_name.to_string name)
          ; Pp.newline
          ; Pp.textf "%s" (Node.to_dyn package_typed |> Dyn.to_string)
          ; Pp.newline
          ; Pp.textf "%s" (Node.to_dyn existing |> Dyn.to_string)
          ]
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
      let all_nodes_in_dependency_order = all_nodes_in_dependency_order dag in
      { dag; all_nodes_in_dependency_order }
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
              Absolute_path.Root_or_non_root.concat_relative_exn
                (Package.root package)
                rel_root
          in
          let package = Package.read_root dep_root in
          (match Package_name.equal (Dependency.name dep) (Package.name package) with
           | true -> package
           | false ->
             user_exn
               [ Pp.textf
                   "The package loaded from %S was expected to be named %S, but got %S \
                    instead."
                   (Either_path.to_filename dir_path)
                   (Dependency.name dep |> Package_name.to_string)
                   (Package.name package |> Package_name.to_string)
               ]))
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
  Dependency_dag.to_string_graph t.dependency_dag.dag
  |> String.Map.add
       ~key:(Package_id.name_v_version_string (Package.id (Package.Typed.package t.root)))
       ~data:
         (Dependency_dag.roots t.dependency_dag.dag
          |> List.map ~f:Node.show
          |> String.Set.of_list)
;;

let dot t = to_string_graph t |> Alice_graphviz.dot_src_of_string_graph

module Package_with_deps = struct
  type ('exe, 'lib) t =
    { package_typed : ('exe, 'lib) Package.Typed.t
    ; dependency_dag : Dependency_dag.t
    ; is_root : bool
    }

  type lib_only_t = (Type_bool.false_t, Type_bool.true_t) t

  let package_typed { package_typed; _ } = package_typed
  let package t = package_typed t |> Package.Typed.package
  let name t = package t |> Package.name
  let id t = package t |> Package.id

  let immediate_deps_in_dependency_order { package_typed; dependency_dag; _ } =
    let immediate_dep_names =
      Package.Typed.package package_typed
      |> Package.dependency_names
      |> Package_name.Set.of_list
    in
    List.filter_map dependency_dag.all_nodes_in_dependency_order ~f:(fun node ->
      if Node.Name.Set.mem (Node.name node) immediate_dep_names
      then Some { package_typed = node; dependency_dag; is_root = false }
      else None)
  ;;

  let transitive_dependency_closure_excluding_package
        { package_typed; dependency_dag; is_root }
    =
    if is_root
    then dependency_dag.all_nodes_in_dependency_order
    else
      Dependency_dag.transitive_closure_in_dependency_order
        dependency_dag.dag
        ~start:(Package.Typed.name package_typed)
        ~include_start:false
  ;;
end

let root_package_with_deps { root; dependency_dag } =
  { Package_with_deps.package_typed = root; is_root = true; dependency_dag }
;;

let transitive_dependency_closure_in_dependency_order { dependency_dag; _ } =
  List.map dependency_dag.all_nodes_in_dependency_order ~f:(fun package_typed ->
    { Package_with_deps.package_typed; is_root = false; dependency_dag })
;;
