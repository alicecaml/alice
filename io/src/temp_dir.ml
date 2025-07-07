open! Alice_stdlib
open Alice_hierarchy

let rng = lazy (Random.State.make_self_init ())

let mkdir ~prefix ~suffix =
  let perms = 0o755 in
  let rng = Lazy.force rng in
  let temp_dir_base = Filename.get_temp_dir_name () in
  let rec loop () =
    let rand_int = Random.State.bits rng land 0xFFFFFFFF in
    let dir_name = sprintf "%s%08x%s" prefix rand_int suffix in
    let path = Filename.concat temp_dir_base dir_name in
    if Sys.file_exists path then loop () else path
  in
  let path = Path.absolute (loop ()) in
  Unix.mkdir (Path.to_filename path) perms;
  path
;;

let with_ ~prefix ~suffix ~f =
  let path = mkdir ~prefix ~suffix in
  let ret = f path in
  File_ops.rm_rf path;
  ret
;;
