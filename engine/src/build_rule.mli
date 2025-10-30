open! Alice_stdlib
open Alice_hierarchy

type t

val to_dyn : t -> Dyn.t
val dynamic : f:(Path.Relative.t -> Origin.Build.t option) -> t
val static : Origin.Build.t -> t

module Database : sig
  type nonrec t = t list

  val create_build_graph : t -> outputs:Path.Relative.t list -> Build_graph.t
end
