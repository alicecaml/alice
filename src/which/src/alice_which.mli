open! Alice_stdlib
open Alice_hierarchy

val which : Alice_env.Os_type.t -> Env.t -> string -> Absolute_path.non_root_t option

val ocaml_toolchain
  :  Alice_env.Os_type.t
  -> Env.t
  -> Alice_ocaml_toolchain.Ocaml_toolchain.t
