open! Alice_stdlib
open Alice_hierarchy

type t

val create : Alice_env.Os_type.t -> Alice_env.Env.t -> t
val base_dir : t -> Absolute_path.non_root_t
val roots_dir : t -> Absolute_path.non_root_t
val current : t -> Absolute_path.non_root_t
val current_bin : t -> Absolute_path.non_root_t
val completions_dir : t -> Absolute_path.non_root_t
val env_dir : t -> Absolute_path.non_root_t
