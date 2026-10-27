open! Alice_stdlib
open Alice_package

(** Builds are orchestrated in the context of a project. This determines things
    like where build artifacts will go, and which package is the root of the
    package dependency graph. *)
type t

val of_package : Package.t -> t
val build : t -> Build_config.t -> built_artifacts_from_deps:bool -> unit

val run
  :  t
  -> Build_config.t
  -> args:string list
  -> built_artifacts_from_deps:bool
  -> unit

val clean : t -> unit
val dot_build_artifacts : t -> Build_config.t -> string
val dot_dependencies : t -> string
val write_dot_merlin_initial : t -> unit
val write_dot_gitignore : t -> unit
