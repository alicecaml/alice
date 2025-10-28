open! Alice_stdlib
open Alice_hierarchy
open Alice_package

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

module Package_build_planner : sig
  type build_plan := t
  type exe_enabled
  type exe_disabled
  type lib_enabled
  type lib_disabled
  type ('exe, 'lib) what
  type exe_only := (exe_enabled, lib_disabled) what
  type lib_only := (exe_disabled, lib_enabled) what
  type exe_and_lib := (exe_enabled, lib_enabled) what
  type 'what t

  val create_exe_only : Ctx.t -> Package.t -> out_dir:Path.Absolute.t -> exe_only t
  val create_lib_only : Ctx.t -> Package.t -> out_dir:Path.Absolute.t -> lib_only t
  val create_exe_and_lib : Ctx.t -> Package.t -> out_dir:Path.Absolute.t -> exe_and_lib t
  val build_exe : (exe_enabled, _) what t -> build_plan
  val build_lib : (_, lib_enabled) what t -> build_plan
  val dot : _ t -> string
end
