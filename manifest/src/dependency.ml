open! Alice_stdlib
open Alice_error
open Alice_hierarchy

type t =
  { name : Package_name.t
  ; version_pattern : Version_pattern.t
  }

let to_dyn { name; version_pattern } =
  Dyn.record
    [ "name", Package_name.to_dyn name
    ; "version_pattern", Version_pattern.to_dyn version_pattern
    ]
;;

module Keys = struct
  module Key = Toml.Types.Table.Key

  let version_pattern = Key.of_string "name"
end

let of_toml ~manifest_path_for_messages ~name toml_value =
  let error pps =
    user_error
      (Pp.textf
         "Error while parsing toml file %S:\n"
         (Path.to_filename manifest_path_for_messages)
       :: pps)
  in
  let parse_version_pattern version_pattern_s =
    match Version_pattern.of_string_res version_pattern_s with
    | Ok version_pattern -> version_pattern
    | Error e -> error e
  in
  match (toml_value : Toml.Types.value) with
  | TString version_pattern_s ->
    let version_pattern = parse_version_pattern version_pattern_s in
    { name; version_pattern }
  | TTable toml_table ->
    let version_pattern_s =
      Fields.parse_field
        ~manifest_path_for_messages
        Keys.version_pattern
        toml_table
        ~f:(function
        | Toml.Types.TString version_pattern_s -> `Ok version_pattern_s
        | _ -> `Expected "string")
    in
    let version_pattern = parse_version_pattern version_pattern_s in
    { name; version_pattern }
  | other ->
    user_error
      [ Pp.textf
          "Error while parsing toml file %S:\n"
          (Path.to_filename manifest_path_for_messages)
      ; Pp.text "Expected dependency to be a table or string, but instead found:\n"
      ; Pp.text (Toml.Printer.string_of_value other)
      ]
;;

let to_toml_except_name { name = _; version_pattern } =
  Toml.Types.TString (Version_pattern.to_string version_pattern)
;;
