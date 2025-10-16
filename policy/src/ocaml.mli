open! Alice_stdlib
open Alice_hierarchy
module Build_plan = Alice_engine.Build_plan

module Ctx : sig
  type t =
    { optimization_level : [ `O2 | `O3 ] option
    ; debug : bool
    }

  val debug : t
  val release : t
end

module Plan : sig
  (** A build plan for an OCaml project, possibly containing a library or
      executable or both. *)
  type t

  val create
    :  Ctx.t
    -> name:Path.Relative.t
    -> exe_root_ml:Path.Relative.t option
    -> lib_root_ml:Path.Relative.t option
    -> src_dir:_ File.dir
    -> build_dir:Path.Absolute.t
    -> t

  val traverse_exe : t -> Build_plan.Traverse.t
  val traverse_lib : t -> Build_plan.Traverse.t
  val build_plan : t -> Build_plan.t
end
