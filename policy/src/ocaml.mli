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

val build_exe
  :  Ctx.t
  -> exe_name:Path.Relative.t
  -> root_ml:Path.Relative.t
  -> src_dir:_ Dir.t
  -> Build_plan.Traverse.t
