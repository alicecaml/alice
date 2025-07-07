open! Alice_stdlib
open Alice_hierarchy

val tar : tarball_file:_ Path.t -> output_dir:_ Path.t -> Command.t
val extract : tarball_file:_ Path.t -> output_dir:_ Path.t -> unit
