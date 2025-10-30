open! Alice_stdlib
open Type_bool
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
val outputs : t -> Path.Absolute.Set.t

(** The build plans that must be evaluated before this build plan. *)
val deps : t -> t list

val create_exe : Profile.t -> (true_t, _) Package.Typed.t -> out_dir:Path.Absolute.t -> t
val create_lib : Profile.t -> (_, true_t) Package.Typed.t -> out_dir:Path.Absolute.t -> t

module Package_build_planner : sig
  type build_plan = t

  (** Type params are expected to be type-level booleans indicating whether the
      package defines an executable and a library respectively. *)
  type ('exe, 'lib) t

  val create
    :  Profile.t
    -> ('exe, 'lib) Package.Typed.t
    -> out_dir:Path.Absolute.t
    -> ('exe, 'lib) t

  val plan_exe : (true_t, _) t -> build_plan
  val plan_lib : (_, true_t) t -> build_plan

  (** Return all build plans appropriate for the type of package. *)
  val all_plans : (_, _) t -> build_plan list

  val dot : _ t -> string
end
