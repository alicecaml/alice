open! Alice_stdlib
open Alice_error
open Alice_hierarchy
module Table = Toml.Types.Table

let parse_field_opt ~manifest_path_for_messages key toml_table ~f =
  Table.find_opt key toml_table
  |> Option.map ~f:(fun value ->
    match f value with
    | `Ok x -> x
    | `Expected expected ->
      user_exn
        [ Pp.textf
            "Error while parsing toml file %S:\n"
            (Absolute_path.to_filename manifest_path_for_messages)
        ; Pp.textf
            "Expected field %S to contain a %s, but instead found:\n"
            (Table.Key.to_string key)
            expected
        ; Pp.text (Toml.Printer.string_of_value value)
        ])
;;

let parse_field ~manifest_path_for_messages key toml_table ~f =
  match parse_field_opt ~manifest_path_for_messages key toml_table ~f with
  | Some value -> value
  | None ->
    user_exn
      [ Pp.textf
          "Error while parsing toml file %S:\nCan't find required field %S."
          (Absolute_path.to_filename manifest_path_for_messages)
          (Table.Key.to_string key)
      ]
;;

let check_for_extraneous_fields ~manifest_path_for_messages ~all_keys toml_table =
  let all_keys = List.map all_keys ~f:Table.Key.to_string |> String.Set.of_list in
  Table.iter
    (fun key _ ->
       let key = Table.Key.to_string key in
       match String.Set.mem key all_keys with
       | false ->
         user_exn
           [ Pp.textf
               "Error while parsing toml file %S:\n"
               (Absolute_path.to_filename manifest_path_for_messages)
           ; Pp.textf "Unexpected key: %s" key
           ]
       | true -> ())
    toml_table
;;
