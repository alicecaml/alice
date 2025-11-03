open! Alice_stdlib
open Alice_error
open Alice_hierarchy

val read : Absolute_path.non_root_t -> (File_non_root.t, [ `Not_found ]) result
val read_dir : Absolute_path.non_root_t -> (File_non_root.dir, User_error.t) result
val read_dir_exn : Absolute_path.non_root_t -> File_non_root.dir
