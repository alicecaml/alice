open! Alice_stdlib
open Alice_error
open Alice_hierarchy
include Alice_package_meta.Dependencies

let of_toml ~manifest_path_for_messages toml =
  Toml.Types.Table.to_list toml
  |> List.map ~f:(fun (key, value) ->
    let package_name =
      match
        Alice_package_meta.Package_name.of_string_res (Toml.Types.Table.Key.to_string key)
      with
      | Ok package_name -> package_name
      | Error pps ->
        user_exn
          (Pp.textf
             "Error while parsing toml file %S:\n"
             (Absolute_path.to_filename manifest_path_for_messages)
           :: pps)
    in
    Dependency.of_toml ~manifest_path_for_messages ~name:package_name value)
  |> of_list
  |> function
  | Ok t -> t
  | Error (`Duplicate_name name) ->
    user_exn
      [ Pp.textf
          "Duplicate package name in dependencies: %s"
          (Alice_package_meta.Package_name.to_string name)
      ]
;;

let to_toml t = Toml.Types.Table.of_list (to_list t |> List.map ~f:Dependency.to_toml)
