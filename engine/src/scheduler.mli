open! Alice_stdlib
open Alice_hierarchy
open Alice_package

module Sequential : sig
  val eval_build_plan
    :  Build_graph.Build_plan.t
    -> Package.t
    -> Profile.t
    -> Build_dir.t
    -> unit
end
