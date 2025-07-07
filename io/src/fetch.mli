open! Alice_stdlib
open Alice_hierarchy

val curl : url:Url.t -> output_file:_ Path.t -> Command.t
val wget : url:Url.t -> output_file:_ Path.t -> Command.t
val fetch : url:Url.t -> output_file:_ Path.t -> unit
