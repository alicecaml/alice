open! Alice_stdlib
open Alice_hierarchy

let entries dir_path =
  let dir_handle = Unix.opendir dir_path in
  let ret =
    Seq.of_dispenser (fun () ->
      match Unix.readdir dir_handle with
      | entry -> Some entry
      | exception End_of_file -> None)
    |> List.of_seq
  in
  Unix.closedir dir_handle;
  ret
;;

(* Lists the names (not the paths) of files from the given directory. *)
let entries_without_current_or_parent dir_path =
  entries dir_path
  |> List.filter ~f:(function
    | "." | ".." -> false
    | _ -> true)
;;

let read base_path =
  match Sys.file_exists (Absolute_path.to_filename base_path) with
  | false -> Error `Not_found
  | true ->
    let rec loop path =
      let stat = Unix.lstat (Absolute_path.to_filename path) in
      let kind =
        match stat.st_kind with
        | S_REG -> File_non_root.Regular
        | S_LNK -> Link
        | S_DIR ->
          let files =
            entries_without_current_or_parent (Absolute_path.to_filename path)
            |> List.map ~f:(fun name ->
              let basename = Basename.of_filename name in
              loop (path / basename))
          in
          Dir files
        | _ -> Unknown
      in
      { path; kind }
    in
    Ok (loop base_path)
;;

let read_dir path =
  match read path with
  | Error `Not_found ->
    Error [ Pp.textf "Directory not found: %s" (Alice_ui.absolute_path_to_string path) ]
  | Ok file ->
    (match File_non_root.as_dir file with
     | Some dir -> Ok dir
     | None ->
       Error [ Pp.textf "%S is not a directory" (Alice_ui.absolute_path_to_string path) ])
;;

let read_dir_exn path =
  match read_dir path with
  | Ok x -> x
  | Error pps -> Alice_error.user_exn pps
;;
