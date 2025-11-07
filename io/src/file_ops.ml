open! Alice_stdlib
open Alice_error
open Alice_hierarchy

let rm_rf path =
  match Read_hierarchy.read path with
  | Error `Not_found ->
    (* Ignore the case when the file is missing as this is the
       behaviour of "rm -f". *)
    ()
  | Ok file ->
    File_non_root.traverse_bottom_up file ~f:(fun file ->
      match (file.kind : File_non_root.kind) with
      | Regular | Link | Unknown -> Unix.unlink (Absolute_path.to_filename file.path)
      | Dir _ ->
        (* The directory will be empty by this point because the traversal is
           bottom-up. *)
        Unix.rmdir (Absolute_path.to_filename file.path))
;;

let mkdir_p_filename path =
  let perms = 0o755 in
  let first, rest =
    match Filename.to_components path with
    | Relative rest -> Filename.current_dir_name, rest
    | Absolute { root; rest } -> root, rest
  in
  List.fold_left
    rest
    ~init:(first, [ first ])
    ~f:(fun (partial_path, partial_paths) component ->
      let partial_path = Filename.concat partial_path component in
      partial_path, partial_path :: partial_paths)
  |> snd
  |> List.rev
  |> List.iter ~f:(fun partial_path ->
    if Sys.file_exists partial_path
    then
      if Sys.is_directory partial_path
      then
        (* Nothing to do *)
        ()
      else
        panic
          [ Pp.textf
              "Encountered existing file %S which is not a directory while recursively \
               creating the directory %S"
              partial_path
              path
          ]
    else Unix.mkdir partial_path perms)
;;

let mkdir_p : type is_root. is_root Absolute_path.t -> unit =
  fun path ->
  match Absolute_path.is_root path with
  | True -> ()
  | False -> mkdir_p_filename (Absolute_path.to_filename path)
;;

let recursive_move_hier_between_dirs ~src_hier ~dst =
  File_non_root.traverse_bottom_up src_hier ~f:(fun src_file ->
    let relative_path_filename =
      Filename.chop_prefix
        (Absolute_path.to_filename src_file.path)
        ~prefix:(Absolute_path.to_filename src_hier.path)
    in
    let dst_path_filename =
      Filename.concat (Absolute_path.to_filename dst) relative_path_filename
    in
    mkdir_p_filename (Filename.dirname dst_path_filename);
    if File_non_root.is_dir src_file
    then (
      (* If the file is a directory then don't call [rename] to move it.
         Instead, create a new directory with the same name using [mkdir_p] and
         delete the original directory. This avoids needing to explicitly
         handle the situation where the destination already exists. We know at
         this point that the source directory is empty, since we're traversing
         the source directory structure bottom-up. This allows us to use
         [Unix.rmdir] rather than [rm_rf], which prevents a mistake in this
         function from accidentally deleting an important directory
         ([Unix.rmdir] only deletes empty directories). *)
      mkdir_p_filename dst_path_filename;
      Unix.rmdir (Absolute_path.to_filename src_file.path))
    else Fileutils.mv (Absolute_path.to_filename src_file.path) dst_path_filename)
;;

let recursive_move_between_dirs ~src ~dst =
  if Sys.file_exists (Absolute_path.to_filename dst)
  then
    if Sys.is_directory (Absolute_path.to_filename dst)
    then ()
    else
      panic
        [ Pp.textf
            "Tried moving files to %S but that file is not a directory."
            (Absolute_path.to_filename dst)
        ]
  else
    panic
      [ Pp.textf
          "Tried moving files to %S but that directory does not exist."
          (Absolute_path.to_filename dst)
      ];
  match Read_hierarchy.read src with
  | Error `Not_found ->
    panic
      [ Pp.textf
          "Tried moving files from %S but that that directory does not exist."
          (Absolute_path.to_filename src)
      ]
  | Ok src_hier ->
    if not (File_non_root.is_dir src_hier)
    then
      panic
        [ Pp.textf
            "Tried moving files from %S but that file is not a directory."
            (Absolute_path.to_filename src)
        ];
    recursive_move_hier_between_dirs ~src_hier ~dst
;;

let cp_rf ~src ~dst =
  Fileutils.cp
    ~recurse:true
    ~force:Force
    [ Absolute_path.to_filename src ]
    (Absolute_path.to_filename dst)
;;

let cp_f ~src ~dst =
  Fileutils.cp
    ~recurse:false
    ~force:Force
    [ Absolute_path.to_filename src ]
    (Absolute_path.to_filename dst)
;;

let exists path = Sys.file_exists (Absolute_path.to_filename path)
let is_directory path = Sys.is_directory (Absolute_path.to_filename path)

let with_out_channel path ~mode ~f =
  let open_channel =
    match mode with
    | `Text -> Out_channel.open_text
    | `Bin -> Out_channel.open_bin
  in
  let channel = open_channel (Absolute_path.to_filename path) in
  let ret = f channel in
  Out_channel.close channel;
  ret
;;

let write_text_file path text =
  with_out_channel path ~mode:`Text ~f:(fun channel ->
    Out_channel.output_string channel text)
;;

let with_in_channel path ~mode ~f =
  let open_channel =
    match mode with
    | `Text -> In_channel.open_text
    | `Bin -> In_channel.open_bin
  in
  let in_channel = open_channel (Absolute_path.to_filename path) in
  let ret = f in_channel in
  In_channel.close in_channel;
  ret
;;

let read_text_file path =
  with_in_channel path ~mode:`Text ~f:(fun channel -> In_channel.input_all channel)
;;

let mtime path =
  let stats = Unix.stat (Absolute_path.to_filename path) in
  stats.st_mtime
;;

let symlink ~src ~dst =
  Unix.symlink (Absolute_path.to_filename src) (Absolute_path.to_filename dst)
;;
