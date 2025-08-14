open! Alice_stdlib
open Alice_error
open Alice_hierarchy

type t = Dependency.t Package_name.Map.t

let empty = Package_name.Map.empty
let to_dyn = Package_name.Map.to_dyn Dependency.to_dyn

let of_toml ~manifest_path_for_messages toml =
  Toml.Types.Table.to_list toml
  |> List.map ~f:(fun (key, value) ->
    let package_name =
      match Package_name.of_string_res (Toml.Types.Table.Key.to_string key) with
      | Ok package_name -> package_name
      | Error pps ->
        user_error
          (Pp.textf
             "Error while parsing toml file %S:\n"
             (Path.to_filename manifest_path_for_messages)
           :: pps)
    in
    let dependency =
      Dependency.of_toml ~manifest_path_for_messages ~name:package_name value
    in
    package_name, dependency)
  |> Package_name.Map.of_list
  |> function
  | Ok t -> t
  | Error (duplicate_name, _, _) ->
    user_error
      [ Pp.textf
          "Duplicate package name in dependencies: %s"
          (Package_name.to_string duplicate_name)
      ]
;;

let to_toml t =
  Toml.Types.Table.of_list
    (Package_name.Map.values t
     |> List.map ~f:(fun (dependency : Dependency.t) ->
       ( Toml.Types.Table.Key.of_string (Package_name.to_string dependency.name)
       , Dependency.to_toml_except_name dependency )))
;;
