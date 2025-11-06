open! Alice_stdlib
open Type_bool
open Alice_hierarchy
open Alice_package_meta

type t

val to_dyn : t -> Dyn.t
val equal : t -> t -> bool
val create : root:Absolute_path.Root_or_non_root.t -> meta:Package_meta.t -> t
val read_root : Absolute_path.Root_or_non_root.t -> t
val root : t -> Absolute_path.Root_or_non_root.t
val meta : t -> Package_meta.t
val id : t -> Package_id.t
val name : t -> Package_name.t
val version : t -> Semantic_version.t
val dependencies : t -> Dependencies.t
val dependency_names : t -> Package_name.t list

(** The file inside the source directory containing the entry point for the
    executable. *)
val exe_root_ml : Basename.t

(** The file inside the source directory containing the entry point for the
    library. *)
val lib_root_ml : Basename.t

val src : Basename.t

(** The path of the directory inside a package where the source code is located *)
val src_dir_path : t -> Absolute_path.non_root_t

val src_dir_exn : t -> File_non_root.dir

module Typed : sig
  type package := t

  type ('exe, 'lib) type_ =
    | Exe_only : (true_t, false_t) type_
    | Lib_only : (false_t, true_t) type_
    | Exe_and_lib : (true_t, true_t) type_

  (** A package with type-level boolean type annotations indicating whether it
      contains an executable or a library or both. *)
  type ('exe, 'lib) t

  type lib_only_t = (false_t, true_t) t
  type exe_only_t = (true_t, false_t) t
  type exe_and_lib_t = (true_t, true_t) t

  val to_dyn : (_, _) t -> Dyn.t
  val equal : ('exe, 'lib) t -> ('exe, 'lib) t -> bool

  (** Ignore the presence of a library in a package containing both a library
      and an executable. *)
  val limit_to_exe_only : exe_and_lib_t -> exe_only_t

  (** Ignore the presence of an executable in a package containing both an
      executable and a library. *)
  val limit_to_lib_only : exe_and_lib_t -> lib_only_t

  val package : (_, _) t -> package
  val name : (_, _) t -> Package_name.t
  val type_ : ('exe, 'lib) t -> ('exe, 'lib) type_
  val contains_exe : ('exe, _) t -> 'exe Type_bool.t
  val contains_lib : (_, 'lib) t -> 'lib Type_bool.t
end

val typed
  :  t
  -> [ `Exe_only of (true_t, false_t) Typed.t
     | `Lib_only of (false_t, true_t) Typed.t
     | `Exe_and_lib of (true_t, true_t) Typed.t
     ]

type 'a with_typed = { f : 'exe 'lib. ('exe, 'lib) Typed.t -> 'a }

val with_typed : 'a with_typed -> t -> 'a
