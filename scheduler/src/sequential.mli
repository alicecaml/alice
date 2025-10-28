open! Alice_stdlib
open Alice_hierarchy

val run
  :  src_dir:Path.Absolute.t
  -> out_dir:Path.Absolute.t
  -> package:Alice_package_meta.Package_id.t
  -> Alice_engine.Build_plan.Traverse.t
  -> unit
