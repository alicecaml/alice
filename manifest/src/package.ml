open! Alice_stdlib
include Alice_package.Package

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
