open! Alice_stdlib
open Alice_hierarchy

val curl : url:string -> output_file:_ Path.t -> Command.t
val wget : url:string -> output_file:_ Path.t -> Command.t
val fetch : url:string -> output_file:_ Path.t -> unit
