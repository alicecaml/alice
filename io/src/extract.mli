open! Alice_stdlib

val tar : tarball_file:Filename.t -> output_dir:Filename.t -> Command.t
val extract : tarball_file:Filename.t -> output_dir:Filename.t -> unit
