open! Alice_stdlib
open Alice_hierarchy

type t

val create : Alice_env.Os_type.t -> Env.t -> t
val local_bin : t -> Absolute_path.non_root_t

(** Path to where the file that will contain the bash completion script for
    Alice. *)
val bash_completion_script_path : t -> Absolute_path.non_root_t

val roots : t -> Absolute_path.non_root_t
val current : t -> Absolute_path.non_root_t
val current_bin : t -> Absolute_path.non_root_t
val env : t -> Absolute_path.non_root_t
