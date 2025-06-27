open! Alice_stdlib
include Alice_hierarchy

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

let entries_without_current_or_parent dir_path =
  entries dir_path
  |> List.filter ~f:(function
    | "." | ".." -> false
    | _ -> true)
;;

module File = struct
  include File

  let read path =
    match Sys.file_exists path with
    | false -> Error `Not_found
    | true ->
      let rec loop path =
        let stat = Unix.lstat path in
        let kind =
          match stat.st_kind with
          | S_REG -> Regular
          | S_LNK ->
            let dest = Unix.readlink path in
            Link dest
          | S_DIR ->
            let files =
              entries_without_current_or_parent path
              |> List.map ~f:(fun name ->
                let path = Filename.concat path name in
                loop path)
            in
            Dir files
          | _ -> Unknown
        in
        { path; kind }
      in
      Ok (loop path)
  ;;
end
