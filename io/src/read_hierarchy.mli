open! Alice_stdlib
module Path := Alice_hierarchy.Path
module File := Alice_hierarchy.File

val read : 'path_kind Path.t -> ('path_kind File.t, [ `Not_found ]) result
