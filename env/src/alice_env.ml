open! Alice_stdlib
open Alice_hierarchy

let initial_cwd = Absolute_path.of_filename (Sys.getcwd ())

module Variable = struct
  type t =
    { name : string
    ; value : string
    }

  let parse s =
    match String.lsplit2 s ~on:'=' with
    | None -> { name = s; value = "" }
    | Some (name, value) -> { name; value }
  ;;

  let to_string { name; value } = sprintf "%s=%s" name value

  let to_dyn { name; value } =
    Dyn.record [ "name", Dyn.string name; "value", Dyn.string value ]
  ;;
end

module Env = struct
  type t = Variable.t list
  type raw = string array

  let to_dyn = Dyn.list Variable.to_dyn
  let of_raw raw = Array.to_list raw |> List.map ~f:Variable.parse
  let to_raw t = List.map t ~f:Variable.to_string |> Array.of_list
  let current () = Unix.environment () |> of_raw

  let get_opt t ~name =
    List.find_map t ~f:(fun (variable : Variable.t) ->
      if String.equal variable.name name then Some variable.value else None)
  ;;

  let contains t ~name =
    List.exists t ~f:(fun (variable : Variable.t) -> String.equal variable.name name)
  ;;

  let set t ~name ~value =
    let variable = { Variable.name; value } in
    if contains t ~name
    then
      List.map t ~f:(fun (v : Variable.t) ->
        if String.equal v.name name then variable else v)
    else variable :: t
  ;;
end

module Path_variable = struct
  type t = Absolute_path.Root_or_non_root.t list

  let to_dyn = Dyn.list Absolute_path.Root_or_non_root.to_dyn
  let name = "PATH"
  let delimiter = if Sys.win32 then ';' else ':'

  let of_raw raw =
    String.split_on_char ~sep:delimiter raw
    |> List.filter ~f:(Fun.negate String.is_empty)
    |> List.map ~f:(fun filename ->
      if Filename.is_relative filename
      then
        `Non_root
          (Absolute_path.Root_or_non_root.concat_relative
             initial_cwd
             (Relative_path.of_filename filename))
      else Absolute_path.of_filename filename)
  ;;

  let to_raw t =
    List.map t ~f:Absolute_path.Root_or_non_root.to_filename
    |> String.concat ~sep:(String.make 1 delimiter)
  ;;

  let get_opt ?(name = name) env = Env.get_opt env ~name |> Option.map ~f:of_raw
  let get_or_empty ?(name = name) env = get_opt ~name env |> Option.value ~default:[]

  let get_result ?(name = name) env =
    match get_opt ~name env with
    | None -> Error (`Variable_not_defined name)
    | Some t -> Ok t
  ;;

  let set ?(name = name) t env = Env.set env ~name ~value:(to_raw t)
end
