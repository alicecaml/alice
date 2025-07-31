open! Alice_stdlib
module Path = Alice_hierarchy.Path.Relative

type t

val to_dyn : t -> Dyn.t
val dynamic : f:(Path.t -> Build_plan.Build.t option) -> t
val static : Build_plan.Build.t -> t

module Database : sig
  type nonrec t = t list

  val create_build_plan : t -> output:Path.t -> Build_plan.t
end
