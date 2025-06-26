open! Alice_stdlib

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

module Dir = struct
  include Alice_hierarchy.Dir

  let read ~dir_path =
    let rec loop dir_path =
      entries_without_current_or_parent dir_path
      |> List.filter_map ~f:(fun entry ->
        let entry_path = Filename.concat dir_path entry in
        let stats = Unix.lstat entry_path in
        match stats.st_kind with
        | S_REG -> Some { kind = Regular; name = entry }
        | S_DIR ->
          let dir = loop entry_path in
          Some { kind = Dir dir; name = entry }
        | S_LNK ->
          let dest = Unix.readlink entry_path in
          Some { kind = Link dest; name = entry }
        | _ -> None)
    in
    let entries = loop dir_path in
    { path = dir_path; entries }
  ;;
end
