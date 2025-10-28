open! Alice_stdlib
open Alice_hierarchy
open Alice_package
open Type_bool

(** A plan for building a set of files. Evaluating a build plan requires first
    evaluating all the build plan's dependencies, which are also build plans. *)
type t

(** The origin of the files produced by this build plan, excluding files
    that would be produces by the build plan's dependencies. *)
val origin : t -> Origin.t

(** The paths to the files that will be produced by this build plan, excluding
    files that would be produced by the build plan's dependencies. *)
val outputs : t -> Path.Relative.Set.t

(** The build plans that must be evaluated before this build plan. *)
val deps : t -> t list

module Ctx : sig
  type t =
    { optimization_level : [ `O2 | `O3 ] option
    ; debug : bool
    }

  val debug : t
  val release : t
end

val create_exe : Ctx.t -> (true_t, _) Package.Typed.t -> out_dir:Path.Absolute.t -> t
val create_lib : Ctx.t -> (_, true_t) Package.Typed.t -> out_dir:Path.Absolute.t -> t

module Package_build_planner : sig
  type build_plan := t

  (** Type params are expected to be type-level booleans indicating whether the
      package defines an executable and a library respectively. *)
  type ('exe, 'lib) t

  val create
    :  Ctx.t
    -> ('exe, 'lib) Package.Typed.t
    -> out_dir:Path.Absolute.t
    -> ('exe, 'lib) t

  val plan_exe : (true_t, _) t -> build_plan
  val plan_lib : (_, true_t) t -> build_plan
  val dot : _ t -> string
end
