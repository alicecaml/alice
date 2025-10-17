open! Alice_stdlib

type t =
  { package : Package.t
  ; dependencies : Dependencies.t option
  }

let to_dyn { package; dependencies } =
  Dyn.record
    [ "package", Package.to_dyn package
    ; "dependencies", Dyn.option Dependencies.to_dyn dependencies
    ]
;;

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
  let package_table =
    Fields.parse_field ~manifest_path_for_messages Keys.package toml_table ~f:(function
      | Toml.Types.TTable table -> `Ok table
      | _ -> `Expected "table")
  in
  let package = Package.of_toml ~manifest_path_for_messages package_table in
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
  { package; dependencies }
;;

let to_toml { package; dependencies } =
  let fields = [ Keys.package, Toml.Types.TTable (Package.to_toml package) ] in
  let fields =
    match dependencies with
    | Some dependencies ->
      fields
      @ [ Keys.dependencies, Toml.Types.TTable (Dependencies.to_toml dependencies) ]
    | None -> fields
  in
  Toml.Types.Table.of_list fields
;;

let to_toml_string t = to_toml t |> Toml.Printer.string_of_table

let dependencies { dependencies; _ } =
  Option.value dependencies ~default:Dependencies.empty
;;
