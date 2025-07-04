open! Alice_stdlib

type t

val create : f:(Filename.t -> Build_plan.Build.t option) -> t
val create_fixed_output : output:Filename.t -> build:Build_plan.Build.t -> t

module Database : sig
  type nonrec t = t list

  val create_build_plan : t -> output:Filename.t -> Build_plan.t
end
