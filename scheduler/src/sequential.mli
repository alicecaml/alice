open! Alice_stdlib
open Alice_hierarchy

val run
  :  src_dir:_ Path.t
  -> out_dir:_ Path.t
  -> package:Alice_manifest.Package.t
  -> Alice_engine.Build_plan.Traverse.t
  -> unit
