open! Alice_stdlib
open Alice_hierarchy
module Build_ctx := Alice_policy.Ocaml.Ctx

val manifest_name : string

type t

val create : root:Path.Absolute.t -> manifest:Alice_package.Package.t -> t
val build_ocaml : ctx:Build_ctx.t -> t -> unit
val run_ocaml_exe : ctx:Build_ctx.t -> t -> args:string list -> unit
val clean : t -> unit

(** Returns the dot (graphviz) source code describing the dependency hierarchy
    of build artifacts. *)
val dot_ocaml : ctx:Build_ctx.t -> t -> string

val new_ocaml : Alice_package.Package_name.t -> _ Path.t -> [ `Exe | `Lib ] -> unit
