open! Alice_stdlib
open Alice_hierarchy

let initial_cwd = Absolute_path.of_filename (Sys.getcwd ())

module Os_type = struct
  type t =
    | Windows
    | Unix

  let current () = if Sys.win32 then Windows else Unix

  let is_windows = function
    | Windows -> true
    | Unix -> false
  ;;

  let filename_add_exe_extension_on_windows t filename_without_extension =
    if Filename.has_extension filename_without_extension ~ext:".exe"
    then
      Alice_error.panic
        [ Pp.textf "File %S already has .exe extension" filename_without_extension ];
    match t with
    | Windows -> Filename.add_extension filename_without_extension ~ext:".exe"
    | Unix -> filename_without_extension
  ;;

  let basename_add_exe_extension_on_windows t basename_without_extension =
    if Basename.has_extension basename_without_extension ~ext:".exe"
    then
      Alice_error.panic
        [ Pp.textf
            "File %S already has .exe extension"
            (Basename.to_filename basename_without_extension)
        ];
    match t with
    | Windows -> Basename.add_extension basename_without_extension ~ext:".exe"
    | Unix -> basename_without_extension
  ;;

  let path_delimiter = function
    | Windows -> ';'
    | Unix -> ':'
  ;;
end

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

  let empty = []
  let to_dyn = Dyn.list Variable.to_dyn
  let of_raw raw = Array.to_list raw |> List.map ~f:Variable.parse
  let to_raw t = List.map t ~f:Variable.to_string |> Array.of_list
  let current () = Unix.environment () |> of_raw

  let get_opt t ~name =
    List.find_map t ~f:(fun (variable : Variable.t) ->
      if String.equal variable.name name then Some variable.value else None)
  ;;

  let find_name_opt t ~f =
    List.find_opt t ~f:(fun (variable : Variable.t) -> f variable.name)
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

  let of_raw os_type raw =
    String.split_on_char ~sep:(Os_type.path_delimiter os_type) raw
    |> List.filter ~f:(Fun.negate String.is_empty)
    |> List.map ~f:(fun filename ->
      if Filename.is_relative filename
      then
        Absolute_path.Root_or_non_root.concat_relative_exn
          initial_cwd
          (Relative_path.of_filename filename)
      else Absolute_path.of_filename filename)
  ;;

  let to_raw os_type t =
    List.map t ~f:Absolute_path.Root_or_non_root.to_filename
    |> String.concat ~sep:(String.make 1 (Os_type.path_delimiter os_type))
  ;;

  let is_path_variable_name os_type name =
    if Os_type.is_windows os_type
    then String.equal (String.uppercase_ascii name) "PATH"
    else String.equal name "PATH"
  ;;

  let get_opt os_type env =
    Env.find_name_opt ~f:(is_path_variable_name os_type) env
    |> Option.map ~f:(fun (variable : Variable.t) -> of_raw os_type variable.value)
  ;;

  let get_or_empty os_type env = get_opt os_type env |> Option.value ~default:[]

  let get_result os_type env =
    match get_opt os_type env with
    | None -> Error (`Variable_not_defined "todo")
    | Some t -> Ok t
  ;;

  let set t os_type env = Env.set env ~name:"PATH" ~value:(to_raw os_type t)
end

module Xdg = struct
  include Alice_stdlib.Xdg

  let create os_type env =
    let env name = Env.get_opt env ~name in
    create ~win32:(Os_type.is_windows os_type) ~env ()
  ;;
end
