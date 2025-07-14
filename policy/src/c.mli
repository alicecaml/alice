open! Alice_stdlib
open Alice_hierarchy
module Rule = Alice_engine.Rule

module Ctx : sig
  (** Settings that affect the way that files will be built *)
  type t =
    { optimization_level : [ `O0 | `O1 | `O2 | `O3 ] option
    ; debug : bool
    ; override_c_compiler : string option
    }

  val debug : t
  val release : t
end

val exe_rules
  :  exe_name:Path.Relative.t
  -> Ctx.t
  -> Path.relative Dir.t
  -> Rule.Database.t
