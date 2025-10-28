open! Alice_stdlib
open Alice_hierarchy
open Alice_package_meta

type t

val to_dyn : t -> Dyn.t
val equal : t -> t -> bool
val create : root:Path.Absolute.t -> meta:Package_meta.t -> t
val read_root : Path.Absolute.t -> t
val root : t -> Path.Absolute.t
val meta : t -> Package_meta.t
val id : t -> Package_id.t
val name : t -> Package_name.t
val version : t -> Semantic_version.t
val dependencies : t -> Dependencies.t

(** The path of the directory inside a package where the source code is located *)
val src_dir_path : t -> Path.Absolute.t

val src_dir_exn : t -> Path.absolute File.dir
val contains_exe : t -> bool
val contains_lib : t -> bool

(** The file inside the source directory containing the entry point for the
    executable, if the project contains an executable. *)
val exe_root_ml : t -> Path.Relative.t

(** The file inside the source directory containing the entry point for the
    library, if the project contains a library. *)
val lib_root_ml : t -> Path.Relative.t
