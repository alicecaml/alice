open! Alice_stdlib
open Alice_error
open Alice_hierarchy

type t = { name : Package_name.t }

let to_dyn { name } = Dyn.record [ "name", Package_name.to_dyn name ]

module Keys = struct
  module Key = Toml.Types.Table.Key

  let name = Key.of_string "name"
  let all = [ name ]
end

let of_toml ~manifest_path_for_messages toml_table =
  Fields.check_for_extraneous_fields
    ~manifest_path_for_messages
    ~all_keys:Keys.all
    toml_table;
  let name =
    Fields.parse_field ~manifest_path_for_messages Keys.name toml_table ~f:(function
      | Toml.Types.TString name -> `Ok name
      | _ -> `Expected "string")
  in
  let name =
    match Package_name.of_string name with
    | Ok name -> name
    | Error pps ->
      user_error
        (Pp.textf
           "Error while parsing toml file %S:\n"
           (Path.to_filename manifest_path_for_messages)
         :: pps)
  in
  { name }
;;

let to_toml { name } =
  Toml.Types.Table.of_list [ Keys.name, Toml.Types.TString (Package_name.to_string name) ]
;;

