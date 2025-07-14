open! Alice_stdlib
module Path = Alice_hierarchy.Path.Relative

type t

val create : f:(Path.t -> Build_plan.Build.t option) -> t
val create_fixed_output : output:Path.t -> build:Build_plan.Build.t -> t

module Database : sig
  type nonrec t = t list

  val create_build_plan : t -> output:Path.t -> Build_plan.t
end
