open! Alice_stdlib

val curl : url:Url.t -> output_file:Filename.t -> Command.t
val wget : url:Url.t -> output_file:Filename.t -> Command.t
val fetch : url:Url.t -> output_file:Filename.t -> unit
