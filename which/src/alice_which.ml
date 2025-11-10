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

(* Add the current root's bin dir from the Alice installation to the end of the
   PATH variable if such a directory exists and isn't already present in PATH.
   This modified environment will be queried to find the location of
   executebles, and executables will run in the modified environment. This way,
   if the user doesn't already have an OCaml toolchain installed, the toolchain
   installed by Alice will be used, and commands from the toolchain can call
   each other. *)
let add_install_dir_to_path_variable os_type env =
  let install_dir = Alice_install_dir.create os_type env in
  let install_dir_bin = Alice_install_dir.current_bin install_dir in
  let path_variable =
    match Path_variable.get_result os_type env with
    | Error `Variable_not_defined -> []
    | Ok path_variable -> path_variable
  in
  if Path_variable.contains path_variable (`Non_root install_dir_bin)
  then
    (* The bin dir from the Alice installation is already in the PATH
       variable, so there's nothing to do. *)
    env
  else if
    Alice_io.File_ops.exists install_dir_bin
    && Alice_io.File_ops.is_directory install_dir_bin
  then (
    (* Only update the PATH variable if the bin dir from the Alice
       installation exists. *)
    let path_variable = path_variable @ [ `Non_root install_dir_bin ] in
    Path_variable.set path_variable os_type env)
  else env
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
    | Error `Variable_not_defined ->
      Alice_log.warn
        [ Pp.text
            "Can't determine program search paths because the PATH variable is not \
             defined."
        ];
      []
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

let ocamlopt_name os_type =
  Alice_env.Os_type.filename_add_exe_extension_on_windows os_type "ocamlopt.opt"
;;

let ocamlopt os_type env =
  let env = add_install_dir_to_path_variable os_type env in
  let filename = try_which os_type env (ocamlopt_name os_type) in
  { Ocaml_compiler.filename; env }
;;
