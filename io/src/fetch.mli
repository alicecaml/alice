open! Alice_stdlib
open Alice_hierarchy

val curl : Env.t -> url:string -> output_file:Absolute_path.non_root_t -> Command.t
val wget : Env.t -> url:string -> output_file:Absolute_path.non_root_t -> Command.t
val fetch : Env.t -> url:string -> output_file:Absolute_path.non_root_t -> unit
