open! Alice_stdlib

module Build : sig
  type t =
    { inputs : Filename.Set.t
    ; commands : Command.t list
    }
end

module Origin : sig
  type t =
    | Source
    | Build of Build.t

  val inputs : t -> Filename.Set.t
end

type t

val to_dyn : t -> Dyn.t

module Staging : sig
  type build_plan := t
  type t

  val to_dyn : t -> Dyn.t
  val add_origin : t -> output:Filename.t -> origin:Origin.t -> t
  val empty : t
  val finalize : t -> build_plan
end
