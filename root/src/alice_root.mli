open! Alice_stdlib
open Alice_hierarchy

val base_dir : unit -> Path.Absolute.t
val roots_dir : unit -> Path.Absolute.t
val current : unit -> Path.Absolute.t
val current_bin : unit -> Path.Absolute.t
val completions_dir : unit -> Path.Absolute.t
val env_dir : unit -> Path.Absolute.t
