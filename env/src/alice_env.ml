open! Alice_stdlib
open Alice_hierarchy

let initial_cwd = Absolute_path.of_filename (Sys.getcwd ())
let current_env () = Unix.environment () |> Env.of_raw

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
    |> Option.map ~f:(of_raw os_type)
  ;;

  let get_or_empty os_type env = get_opt os_type env |> Option.value ~default:[]

  let get_result os_type env =
    match get_opt os_type env with
    | None -> Error `Variable_not_defined
    | Some t -> Ok t
  ;;

  let contains t path = List.exists t ~f:(Absolute_path.Root_or_non_root.equal path)

  let set t os_type env =
    (* Set the PATH variable. Note that on Windows, the PATH variable is
       sometimes referred to in non-uppercase, however it's case insensitive on
       Windows so setting it by an all uppercase name should be fine. *)
    Env.set env ~name:"PATH" ~value:(to_raw os_type t)
  ;;
end

module Xdg = struct
  include Alice_stdlib.Xdg

  let create os_type env =
    let env name = Env.get_opt env ~name in
    create ~win32:(Os_type.is_windows os_type) ~env ()
  ;;
end
