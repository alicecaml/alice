open! Alice_stdlib
open Alice_hierarchy

val tar
  :  tarball_file:Absolute_path.non_root_t
  -> output_dir:Absolute_path.non_root_t
  -> Command.t

val extract
  :  tarball_file:Absolute_path.non_root_t
  -> output_dir:Absolute_path.non_root_t
  -> unit
