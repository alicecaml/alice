open! Alice_stdlib
include Alice_package_meta.Package_meta

module Keys = struct
  module Key = Toml.Types.Table.Key

  let package = Key.of_string "package"
  let dependencies = Key.of_string "dependencies"
  let all = [ package; dependencies ]
end

let of_toml ~manifest_path_for_messages toml_table =
  Fields.check_for_extraneous_fields
    ~manifest_path_for_messages
    ~all_keys:Keys.all
    toml_table;
  let metadata_table =
    (* General metadata is under a key "package" in the manifet *)
    Fields.parse_field ~manifest_path_for_messages Keys.package toml_table ~f:(function
      | Toml.Types.TTable table -> `Ok table
      | _ -> `Expected "table")
  in
  let id = Package_id.of_toml ~manifest_path_for_messages metadata_table in
  let dependencies =
    Fields.parse_field_opt
      ~manifest_path_for_messages
      Keys.dependencies
      toml_table
      ~f:(function
      | Toml.Types.TTable dependencies ->
        `Ok (Dependencies.of_toml ~manifest_path_for_messages dependencies)
      | _ -> `Expected "table")
  in
  create ~id ~dependencies
;;

let to_toml t =
  let fields = [ Keys.package, Toml.Types.TTable (Package_id.to_toml (id t)) ] in
  let fields =
    match dependencies_ t with
    | Some dependencies ->
      fields
      @ [ Keys.dependencies, Toml.Types.TTable (Dependencies.to_toml dependencies) ]
    | None -> fields
  in
  Toml.Types.Table.of_list fields
;;

let node_to_string node =
  let () = Kdl.pp_node Format.str_formatter node in
  Format.flush_str_formatter ()
;;

let annot_value_to_string annot_value =
  let () = Kdl.pp_annot_value Format.str_formatter annot_value in
  Format.flush_str_formatter ()
;;

let prop_to_string prop =
  let () = Kdl.pp_prop Format.str_formatter prop in
  Format.flush_str_formatter ()
;;

let value_to_string value =
  let () = Kdl.pp_value Format.str_formatter value in
  Format.flush_str_formatter ()
;;

let of_kdl_node (kdl_node : Kdl.node) =
  print_endline (sprintf "a %s" (node_to_string kdl_node));
  let children = kdl_node.children in
  List.iter children ~f:(fun child ->
    let s = node_to_string child in
    print_endline (sprintf "b %s" s);
    match child.name with
    | "name" ->
      let args = child.args in
      List.iter args ~f:(fun arg ->
        print_endline (sprintf "c %s" (annot_value_to_string arg)))
    | "version" ->
      let args = child.args in
      List.iter args ~f:(fun arg ->
        print_endline (sprintf "d %s" (annot_value_to_string arg)))
    | "dependencies" ->
      List.iter child.children ~f:(fun child ->
        let s = node_to_string child in
        print_endline (sprintf "e %s %s" child.name s);
        List.iter child.props ~f:(fun prop ->
          print_endline
            (sprintf
               "f %s %s %s"
               (prop_to_string prop)
               (fst prop)
               (value_to_string (snd (snd prop))))))
    | _ -> ())
;;
