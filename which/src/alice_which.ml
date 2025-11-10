open! Alice_stdlib
open Alice_hierarchy
open Alice_env

module Ocaml_compiler = struct
  type t =
    { filename : Filename.t
    ; env : Env.t
    }

  let filename { filename; _ } = filename
  let env { env; _ } = env
  let command { filename; env } ~args = Command.create filename ~args env
end

let find_in_search_path exe_name search_paths =
  List.find_map search_paths ~f:(fun search_path ->
    let exe_path = Absolute_path.Root_or_non_root.concat_basename search_path exe_name in
    if Alice_io.File_ops.exists exe_path then Some exe_path else None)
;;

let which os_type env exe_name =
  let exe_name =
    if Os_type.is_windows os_type && not (Filename.has_extension exe_name ~ext:".exe")
    then (
      let exe_name_with_extension = Filename.add_extension exe_name ~ext:".exe" in
      Alice_log.warn
        [ Pp.textf
            "Looking up location of program %S which lacks \".exe\" extension. Assuming \
             you meant %S."
            exe_name
            exe_name_with_extension
        ];
      exe_name_with_extension)
    else exe_name
  in
  let search_paths =
    match Path_variable.get_result os_type env with
    | Ok search_paths -> search_paths
    | Error (`Variable_not_defined name) ->
      Alice_log.warn
        [ Pp.textf
            "Can't determine program search paths because environment variable %S is not \
             defined."
            name
        ];
      []
  in
  (* Append the bin directory managed by alice to the search paths. This way
     if ocaml isn't installed by any other means and alice has installed
     ocaml tools then we'll still be able to build ocaml programs even if the
     tools are not in the user's PATH variable. *)
  let search_paths =
    search_paths
    @ [ `Non_root (Alice_install_dir.create os_type env |> Alice_install_dir.current_bin)
      ]
  in
  find_in_search_path (Basename.of_filename exe_name) search_paths
;;

let try_which os_type env exe_name =
  match which os_type env exe_name with
  | Some path -> Absolute_path.to_filename path
  | None ->
    (* Couldn't find the executable in PATH, so just return its name just in
       case the OS has some tricks up its sleeve for finding executables. *)
    exe_name
;;

let current_sys_exe_name os_type exe_name_without_extension =
  Alice_env.Os_type.filename_add_exe_extension_on_windows
    os_type
    exe_name_without_extension
;;

let ocamlopt_name os_type = current_sys_exe_name os_type "ocamlopt.opt"

let ocamlopt os_type env =
  let filename = try_which os_type env (ocamlopt_name os_type) in
  { Ocaml_compiler.filename; env }
;;
