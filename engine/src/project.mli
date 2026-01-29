open! Alice_stdlib
open Alice_package
open Alice_hierarchy
open Alice_ocaml_compiler

(** Builds are orchestrated in the context of a project. This determines things
    like where build artifacts will go, and which package is the root of the
    package dependency graph. *)
type t

val of_package : Package.t -> t

val build
  :  t
  -> _ Eio.Process.mgr
  -> Profile.t
  -> Alice_env.Os_type.t
  -> Ocaml_compiler.t
  -> Scheduler.Jobs.t
  -> unit

val run
  :  t
  -> _ Eio.Process.mgr
  -> Profile.t
  -> Alice_env.Os_type.t
  -> Ocaml_compiler.t
  -> Scheduler.Jobs.t
  -> args:string list
  -> unit

val clean : t -> unit
val dot_build_artifacts : t -> Alice_env.Os_type.t -> Ocaml_compiler.t -> string
val dot_dependencies : t -> string
val build_dir_path_relative_to_project_root : Basename.t
val write_dot_merlin_initial : t -> unit
val write_dot_gitignore : t -> unit
