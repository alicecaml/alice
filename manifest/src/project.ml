open! Alice_stdlib

type t = { package : Package.t }

let to_dyn { package } = Dyn.record [ "package", Package.to_dyn package ]

module Keys = struct
  module Key = Toml.Types.Table.Key

  let package = Key.of_string "package"
  let all = [ package ]
end

let of_toml ~manifest_path_for_messages toml_table =
  Fields.check_for_extraneous_fields
    ~manifest_path_for_messages
    ~all_keys:Keys.all
    toml_table;
  let package_table =
    Fields.parse_field ~manifest_path_for_messages Keys.package toml_table ~f:(function
      | Toml.Types.TTable table -> `Ok table
      | _ -> `Expected "table")
  in
  let package = Package.of_toml ~manifest_path_for_messages package_table in
  { package }
;;

let to_toml { package } =
  Toml.Types.Table.of_list [ Keys.package, Toml.Types.TTable (Package.to_toml package) ]
;;

let to_toml_string t = to_toml t |> Toml.Printer.string_of_table
