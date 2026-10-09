open! Alice_stdlib
open Alice_hierarchy

val which : Alice_env.Os_type.t -> Env.t -> string -> Absolute_path.non_root_t option
val ocamlopt : Alice_env.Os_type.t -> Env.t -> Alice_ocaml_compiler.Ocaml_compiler.t
