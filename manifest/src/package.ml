open! Alice_stdlib
open Alice_error
open Alice_hierarchy

type t =
  { name : Package_name.t
  ; version : Semantic_version.t
  }

let to_dyn { name; version } =
  Dyn.record
    [ "name", Package_name.to_dyn name; "version", Semantic_version.to_dyn version ]
;;

module Keys = struct
  module Key = Toml.Types.Table.Key

  let name = Key.of_string "name"
  let version = Key.of_string "version"
  let all = [ name; version ]
end

let of_toml ~manifest_path_for_messages toml_table =
  let error pps =
    user_error
      (Pp.textf
         "Error while parsing toml file %S:\n"
         (Path.to_filename manifest_path_for_messages)
       :: pps)
  in
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
    match Package_name.of_string_res name with
    | Ok name -> name
    | Error pps -> error pps
  in
  let version =
    Fields.parse_field ~manifest_path_for_messages Keys.version toml_table ~f:(function
      | Toml.Types.TString version -> `Ok version
      | _ -> `Expected "string")
  in
  let version =
    match Semantic_version.of_string_res version with
    | Ok version -> version
    | Error pps -> error pps
  in
  { name; version }
;;

let to_toml { name; version } =
  Toml.Types.Table.of_list
    [ Keys.name, Toml.Types.TString (Package_name.to_string name)
    ; Keys.version, Toml.Types.TString (Semantic_version.to_string version)
    ]
;;
