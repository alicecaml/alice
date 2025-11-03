open! Alice_stdlib
open Alice_hierarchy

val base_dir : unit -> Absolute_path.non_root_t
val roots_dir : unit -> Absolute_path.non_root_t
val current : unit -> Absolute_path.non_root_t
val current_bin : unit -> Absolute_path.non_root_t
val completions_dir : unit -> Absolute_path.non_root_t
val env_dir : unit -> Absolute_path.non_root_t
