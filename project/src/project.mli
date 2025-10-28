open! Alice_stdlib
open Alice_hierarchy
module Build_ctx := Alice_build_plan.Build_plan.Ctx

type t

val of_package : Alice_package.Package.t -> t
val build_ocaml : ctx:Build_ctx.t -> t -> unit
val run_ocaml_exe : ctx:Build_ctx.t -> t -> args:string list -> unit
val clean : t -> unit

(** Returns the dot (graphviz) source code describing the dependency hierarchy
    of build artifacts. *)
val dot_build_artifacts : t -> string

val dot_package_dependencies : t -> string
val new_ocaml : Alice_package_meta.Package_name.t -> _ Path.t -> [ `Exe | `Lib ] -> unit
