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
    File.traverse_bottom_up file ~f:(fun file ->
      match (file.kind : _ File.kind) with
      | Regular | Link | Unknown -> Unix.unlink (Path.to_filename file.path)
      | Dir _ ->
        (* The directory will be empty by this point because the traversal is
           bottom-up. *)
        Unix.rmdir (Path.to_filename file.path))
;;

let mkdir_p_filename path =
  let perms = 0o755 in
  let (first :: rest) = Filename.to_components path in
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

let mkdir_p path = mkdir_p_filename (Path.to_filename path)

let recursive_move_hier_between_dirs ~src_hier ~dst =
  File.traverse_bottom_up src_hier ~f:(fun src_file ->
    let relative_path = Path.chop_prefix src_file.path ~prefix:src_hier.path in
    let dst_path = Path.concat dst relative_path in
    mkdir_p_filename (Filename.dirname (Path.to_filename dst_path));
    if File.is_dir src_file
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
      mkdir_p dst_path;
      Unix.rmdir (Path.to_filename src_file.path))
    else Fileutils.mv (Path.to_filename src_file.path) (Path.to_filename dst_path))
;;

let recursive_move_between_dirs ~src ~dst =
  if Sys.file_exists (Path.to_filename dst)
  then
    if Sys.is_directory (Path.to_filename dst)
    then ()
    else
      panic
        [ Pp.textf
            "Tried moving files to %S but that file is not a directory."
            (Path.to_filename dst)
        ]
  else
    panic
      [ Pp.textf
          "Tried moving files to %S but that directory does not exist."
          (Path.to_filename dst)
      ];
  match Read_hierarchy.read src with
  | Error `Not_found ->
    panic
      [ Pp.textf
          "Tried moving files from %S but that that directory does not exist."
          (Path.to_filename src)
      ]
  | Ok src_hier ->
    if not (File.is_dir src_hier)
    then
      panic
        [ Pp.textf
            "Tried moving files from %S but that file is not a directory."
            (Path.to_filename src)
        ];
    recursive_move_hier_between_dirs ~src_hier ~dst
;;
