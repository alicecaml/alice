module Dir := Alice_hierarchy.File.Dir
module Abstract_rule := Alice_engine.Abstract_rule

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

val exe_rules : exe_name:string -> Ctx.t -> Dir.t -> Abstract_rule.t list
