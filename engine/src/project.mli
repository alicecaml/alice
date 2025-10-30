open! Alice_stdlib
open Alice_package
open Alice_hierarchy

(** Builds are orchestrated in the context of a project. This determines things
    like where build artifacts will go, and which package is the root of the
    package dependency graph. *)
type t

val of_package : Package.t -> t
val build : t -> Profile.t -> unit
val run : t -> Profile.t -> args:string list -> unit
val clean : t -> unit
val dot_build_artifacts : t -> string
val dot_dependencies : t -> string
val build_dir_path_relative_to_project_root : Path.Relative.t
