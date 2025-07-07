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
  match Sys.file_exists (Path.to_filename base_path) with
  | false -> Error `Not_found
  | true ->
    let rec loop path =
      let stat = Unix.lstat (Path.to_filename path) in
      let kind =
        match stat.st_kind with
        | S_REG -> File.Regular
        | S_LNK -> Link
        | S_DIR ->
          let files =
            entries_without_current_or_parent (Path.to_filename path)
            |> List.map ~f:(fun name ->
              match Path.of_filename name with
              | `Absolute _ ->
                Alice_error.panic
                  [ Pp.textf "Unexpected absolute path in direcotry entry: %s" name ]
              | `Relative name ->
                let path = Path.concat path name in
                loop path)
          in
          Dir files
        | _ -> Unknown
      in
      { path; kind }
    in
    Ok (loop base_path)
;;
