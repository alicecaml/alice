open! Alice_stdlib
open Alice_package

module Package = struct
  module Name = Package_name
  include Package

  let dep_names t = dependencies t |> Dependencies.names |> Package_name.Set.of_list
  let show t = Package.id t |> Package_id.name_v_version_string
end

include Alice_dag.Make (Package)

module Traverse = struct
  include Traverse

  let package = node
end

let traverse t ~package_name = traverse t ~name:package_name

module Staging = struct
  include Staging

  let add_package t package =
    let name = Package.name package in
    match add t name package with
    | Ok t -> t
    | Error (`Conflict _) ->
      Alice_error.panic
        [ Pp.textf "Conflicting packages with name: %s" (Package_name.to_string name) ]
  ;;

  let finalize t =
    match finalize t with
    | Ok t -> t
    | Error (`Dangling dangling) ->
      Alice_error.panic
        [ Pp.textf "No package with name: %s" (Package_name.to_string dangling) ]
    | Error (`Cycle cycle) ->
      Alice_error.panic
        ([ Pp.text "Dependency cycle:"; Pp.newline ]
         @ List.concat_map cycle ~f:(fun file ->
           [ Pp.textf " - %s" (Package_name.to_string file); Pp.newline ]))
  ;;
end
