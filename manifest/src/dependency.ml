open! Alice_stdlib
open Alice_error
open Alice_hierarchy
open Alice_package_meta
include Dependency

module Keys = struct
  module Key = Toml.Types.Table.Key

  let path = Key.of_string "path"
  let all = [ path ]
end

let of_toml ~manifest_path_for_messages ~name toml_value =
  match (toml_value : Toml.Types.value) with
  | TTable toml_table ->
    Fields.check_for_extraneous_fields
      ~manifest_path_for_messages
      ~all_keys:Keys.all
      toml_table;
    let path =
      Fields.parse_field ~manifest_path_for_messages Keys.path toml_table ~f:(function
        | Toml.Types.TString path -> `Ok (Either_path.of_filename path)
        | _ -> `Expected "string")
    in
    let source = Dependency_source.Local_directory path in
    Dependency.create ~name ~source
  | other ->
    user_exn
      [ Pp.textf
          "Error while parsing toml file %S:\n"
          (Absolute_path.to_filename manifest_path_for_messages)
      ; Pp.text "Expected dependency to be a table or string, but instead found:\n"
      ; Pp.text (Toml.Printer.string_of_value other)
      ]
;;

let to_toml t =
  let name = Dependency.name t in
  let source = Dependency.source t in
  let (Dependency_source.Local_directory path) = source in
  let table =
    [ Keys.path, Toml.Types.TString (Either_path.to_filename path) ]
    |> Toml.Types.Table.of_key_values
  in
  let rhs = Toml.Types.TTable table in
  let lhs = Toml.Types.Table.Key.of_string (Package_name.to_string name) in
  lhs, rhs
;;
