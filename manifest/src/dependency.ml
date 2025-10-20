open! Alice_stdlib
open Alice_error
open Alice_hierarchy

type t =
  { name : Package_name.t
  ; path : Path.Either.t
  }

let to_dyn { name; path } =
  Dyn.record [ "name", Package_name.to_dyn name; "path", Path.Either.to_dyn path ]
;;

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
        | Toml.Types.TString path -> `Ok (Path.of_filename path)
        | _ -> `Expected "string")
    in
    { name; path }
  | other ->
    user_exn
      [ Pp.textf
          "Error while parsing toml file %S:\n"
          (Path.to_filename manifest_path_for_messages)
      ; Pp.text "Expected dependency to be a table or string, but instead found:\n"
      ; Pp.text (Toml.Printer.string_of_value other)
      ]
;;

let to_toml { name; path } =
  let table =
    [ Keys.path, Toml.Types.TString (Path.Either.to_filename path) ]
    |> Toml.Types.Table.of_key_values
  in
  let rhs = Toml.Types.TTable table in
  let lhs = Toml.Types.Table.Key.of_string (Package_name.to_string name) in
  lhs, rhs
;;
