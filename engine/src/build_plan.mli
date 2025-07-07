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
  val to_dyn : t -> Dyn.t
end

module Traverse : sig
  type t

  val output : t -> Filename.t
  val origin : t -> Origin.t
  val deps : t -> t list
end

type t

val to_dyn : t -> Dyn.t
val traverse : t -> output:Filename.t -> Traverse.t option

module Staging : sig
  type build_plan := t
  type t

  val to_dyn : t -> Dyn.t
  val add_origin : t -> output:Filename.t -> origin:Origin.t -> t
  val empty : t

  (** [finalize t] ensures that [t] contains no cycles and all input files have
      a corresponding node in the build graph, returning the validated build
      plan. *)
  val finalize : t -> build_plan
end
