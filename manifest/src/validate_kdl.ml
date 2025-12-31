open! Alice_stdlib
open Alice_package_meta

let simple_string_node (node : Kdl.node) =
  match node with
  | { annot = Some annot; _ } ->
    Error [ Pp.textf "Node %S must not have type annotation. Found: %S." node.name annot ]
  | { props; _ } when not (List.is_empty props) ->
    Format.pp_print_list Kdl.pp_prop Format.str_formatter props;
    let props_s = Format.flush_str_formatter () in
    Error [ Pp.textf "Node %S must not have properties. Found: %S." node.name props_s ]
  | { children; _ } when not (List.is_empty children) ->
    Format.pp_print_list Kdl.pp_node Format.str_formatter children;
    let children_s = Format.flush_str_formatter () in
    Error [ Pp.textf "Node %S must not have children. Found:\n%S" node.name children_s ]
  | { args = []; _ } ->
    Error
      [ Pp.textf
          "Node %S must have a single string argument. No argument found."
          node.name
      ]
  | { args = _ :: _ :: _; _ } ->
    Format.pp_print_list Kdl.pp_annot_value Format.str_formatter node.args;
    let args_s = Format.flush_str_formatter () in
    Error
      [ Pp.textf
          "Node %S must have a single string argument. Multiple arguments found: %S"
          node.name
          args_s
      ]
  | { args = [ (Some annot, _) ]; _ } ->
    Error [ Pp.textf "Node %S must not have type annotations. Found: %S" node.name annot ]
  | { args = [ (None, `String string_arg) ]; _ } -> Ok string_arg
  | { args = [ (None, arg) ]; _ } ->
    Kdl.pp_value Format.str_formatter arg;
    let arg_s = Format.flush_str_formatter () in
    Error [ Pp.textf "Node %S must have a string argument. Found: %S" node.name arg_s ]
;;

module Dependency_field_names = struct
  let path = "path"
end

let dependency_node (node : Kdl.node) =
  match node with
  | { annot = Some annot; _ } ->
    Error
      [ Pp.textf
          "Dependency node (%S) must not have type annotation. Found: %S."
          node.name
          annot
      ]
  | { args; _ } when not (List.is_empty args) ->
    Format.pp_print_list Kdl.pp_annot_value Format.str_formatter args;
    let args_s = Format.flush_str_formatter () in
    Error
      [ Pp.textf
          "Dependency node (%S) must not have arguments. Found %S."
          node.name
          args_s
      ]
  | { children; _ } when not (List.is_empty children) ->
    Format.pp_print_list Kdl.pp_node Format.str_formatter children;
    let children_s = Format.flush_str_formatter () in
    Error
      [ Pp.textf
          "Dependedncy node (%S) must not have children. Found:\n%S"
          node.name
          children_s
      ]
  | { props; _ } ->
    let find_prop name =
      List.find_map props ~f:(fun (name_, annot_value) ->
        if String.equal name name_ then Some annot_value else None)
    in
    let module F = Dependency_field_names in
    (match find_prop F.path with
     | None -> Error [ Pp.textf "Dependency node (%S) lacks field %S" node.name F.path ]
     | Some (Some type_annot, _) ->
       Error
         [ Pp.textf
             "Dependency node (%S) has unexpected type annotation for %S field: %S"
             node.name
             F.path
             type_annot
         ]
     | Some (None, `String value) ->
       let open Result.O in
       let+ name = Package_name.of_string_res node.name in
       let path = Alice_hierarchy.Either_path.of_filename value in
       let source = Dependency_source.Local_directory path in
       Dependency.create ~name ~source
     | Some (None, value) ->
       Kdl.pp_value Format.str_formatter value;
       let value_s = Format.flush_str_formatter () in
       Error
         [ Pp.textf
             "Dependendcy node (%S) has unexpected value type for %S field: %S"
             node.name
             F.path
             value_s
         ])
;;

let dependencies_node (node : Kdl.node) =
  match node with
  | { annot = Some annot; _ } ->
    Error [ Pp.textf "Node %S must not have type annotation. Found %S." node.name annot ]
  | { args; _ } when not (List.is_empty args) ->
    Format.pp_print_list Kdl.pp_annot_value Format.str_formatter args;
    let args_s = Format.flush_str_formatter () in
    Error [ Pp.textf "Node %S must not have arguments. Found %S." node.name args_s ]
  | { props; _ } when not (List.is_empty props) ->
    Format.pp_print_list Kdl.pp_prop Format.str_formatter props;
    let props_s = Format.flush_str_formatter () in
    Error [ Pp.textf "Node %S must not have properties. Found %S." node.name props_s ]
  | { children; _ } ->
    let open Result.O in
    let* dependencies = Result.List.all (List.map children ~f:dependency_node) in
    Dependencies.of_list dependencies
    |> Result.map_error ~f:(function `Duplicate_name name ->
        [ Pp.textf
            "Node %S lists the following package name multiple times: %S"
            node.name
            (Package_name.to_string name)
        ])
;;

module Package_field_names = struct
  let name = "name"
  let version = "version"
  let dependencies = "dependencies"
  let all = [ name; version; dependencies ]
end

let package_node_children (children : Kdl.node list) =
  let find_node name =
    List.find_opt children ~f:(fun (node : Kdl.node) -> String.equal node.name name)
  in
  let module F = Package_field_names in
  let name = find_node F.name in
  let version = find_node F.version in
  let dependencies = find_node F.dependencies in
  match name, version with
  | None, _ -> Error [ Pp.textf "Node \"package\" is missing required field: %S" F.name ]
  | _, None ->
    Error [ Pp.textf "Node \"package\" is missing required field: %S" F.version ]
  | Some name, Some version ->
    let open Result.O in
    let* name = simple_string_node name >>= Package_name.of_string_res in
    let* version = simple_string_node version >>= Semantic_version.of_string_res in
    let id = { Package_id.name; version } in
    let* dependencies =
      match dependencies with
      | None -> Ok None
      | Some dependencies ->
        let+ dependencies = dependencies_node dependencies in
        Some dependencies
    in
    let meta = Package_meta.create ~id ~dependencies in
    Ok meta
;;

let package_node (package_node : Kdl.node) =
  match package_node with
  | { name; _ } when not (String.equal name "package") ->
    Error
      [ Pp.textf "Top-level node must be named \"package\". Found %S." package_node.name ]
  | { annot = Some annot; _ } ->
    Error [ Pp.textf "Top-level node must not have type annotation. Found %S." annot ]
  | { args; _ } when not (List.is_empty args) ->
    Format.pp_print_list Kdl.pp_annot_value Format.str_formatter args;
    let args_s = Format.flush_str_formatter () in
    Error [ Pp.textf "Top-level node must not have arguments. Found %S." args_s ]
  | { props; _ } when not (List.is_empty props) ->
    Format.pp_print_list Kdl.pp_prop Format.str_formatter props;
    let props_s = Format.flush_str_formatter () in
    Error [ Pp.textf "Top-level node must not have properties. Found %S." props_s ]
  | { children; _ } -> package_node_children children
;;

let document (document : Kdl.t) =
  match document with
  | [] ->
    Error
      [ Pp.text
          "Document is empty. Document should contain a single top-level node named \
           \"package\"."
      ]
  | [ node ] -> package_node node
  | _ :: _ :: _ ->
    Error
      [ Pp.text
          "Multiple top-level nodes. Document should contain a single top-level node \
           named \"package\"."
      ]
;;
