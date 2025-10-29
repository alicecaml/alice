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

module Typed : sig
  type package := t

  type ('exe, 'lib) type_ =
    | Exe_only : (true_t, false_t) type_
    | Lib_only : (false_t, true_t) type_
    | Exe_and_lib : (true_t, true_t) type_

  (** A package with type-level boolean type annotations indicating whether it
      contains an executable or a library or both. *)
  type ('exe, 'lib) t

  (** Ignore the presence of a library in a package containing both a library
      and an executable. *)
  val limit_to_exe_only : (true_t, true_t) t -> (true_t, false_t) t

  (** Ignore the presence of an executable in a package containing both an
      executable and a library. *)
  val limit_to_lib_only : (true_t, true_t) t -> (false_t, true_t) t

  val package : (_, _) t -> package
  val type_ : ('exe, 'lib) t -> ('exe, 'lib) type_

  (** The file inside the source directory containing the entry point for the
    executable. *)
  val exe_root_ml : (true_t, _) t -> Path.Relative.t

  (** The file inside the source directory containing the entry point for the
    library. *)
  val lib_root_ml : (_, true_t) t -> Path.Relative.t
end

val typed
  :  t
  -> [ `Exe_only of (true_t, false_t) Typed.t
     | `Lib_only of (false_t, true_t) Typed.t
     | `Exe_and_lib of (true_t, true_t) Typed.t
     ]
