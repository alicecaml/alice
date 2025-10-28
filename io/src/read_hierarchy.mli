open! Alice_stdlib
open Alice_error
module Path := Alice_hierarchy.Path
module File := Alice_hierarchy.File

val read : 'path_kind Path.t -> ('path_kind File.t, [ `Not_found ]) result
val read_dir : 'path_kind Path.t -> ('path_kind File.dir, User_error.t) result
val read_dir_exn : 'path_kind Path.t -> 'path_kind File.dir
