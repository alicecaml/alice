open! Alice_stdlib
open Alice_hierarchy
open Alice_env

let find_in_search_path exe_name search_paths =
  List.find_map search_paths ~f:(fun search_path ->
    let exe_path = Path.concat search_path exe_name in
    if Alice_io.File_ops.exists exe_path then Some (Path.to_either exe_path) else None)
;;

let which exe_name =
  let exe_name =
    if Sys.win32 && not (Filename.has_extension exe_name ~ext:".exe")
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
    match Path_variable.get_result (Env.current ()) with
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
  let search_paths = search_paths @ [ Alice_root.current_bin () ] in
  find_in_search_path (Path.relative exe_name) search_paths
;;

let try_which exe_name =
  match which exe_name with
  | Some path -> Path.Either.to_filename path
  | None ->
    (* Couldn't find the executable in PATH, so just return its name just in
       case the OS has some tricks up its sleeve for finding executables. *)
    exe_name
;;

let current_sys_exe_name exe_name_without_extension =
  if Sys.win32
  then Filename.add_extension exe_name_without_extension ~ext:".exe"
  else exe_name_without_extension
;;

let ocamlopt_name = current_sys_exe_name "ocamlopt.opt"
let ocamlopt () = try_which ocamlopt_name
