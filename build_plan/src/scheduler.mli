open! Alice_stdlib
open Alice_hierarchy
open Alice_package

module Sequential : sig
  val eval_build_plan : Build_plan.t -> Package.t -> out_dir:Path.Absolute.t -> unit
end
