open! Alice_stdlib
module File = Hierarchy.File

let rm_rf path =
  match File.read path with
  | Error `Not_found ->
    (* Ignore the case when the file is missing as this is the
       behaviour of "rm -f". *)
    ()
  | Ok file ->
    File.traverse_bottom_up file ~f:(fun file ->
      match (file.kind : File.kind) with
      | Regular | Link _ | Unknown -> Unix.unlink file.path
      | Dir _ ->
        (* The directory will be empty by this point because the traversal is
           bottom-up. *)
        Unix.rmdir file.path)
;;
