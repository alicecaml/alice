module Ctx : sig
  (** Settings that affect the way that files will be built *)
  type t =
    { optimization_level : [ `O0 | `O1 | `O2 | `O3 ] option
    ; debug : bool
    ; override_c_compiler : string option
    }
end
