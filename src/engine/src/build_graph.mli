open! Alice_stdlib
open Alice_package
open Alice_hierarchy
open Type_bool

module Build_plan : sig
  type t

  val equal : t -> t -> bool
  val deps : t -> t list
  val op : t -> Op.t
  val src_input : t -> Absolute_path.non_root_t option
  val generated_inputs : t -> Op.Gen_file.t list
  val outputs : t -> Op.Gen_file.Set.t
  val transitive_closure : t -> t list
  val transitive_closure_outputs : t -> Op.Gen_file.Set.t
end

(** A DAG that knows how to build a collection of interdependent files and the
    dependencies between each file. *)
type ('exe, 'lib) t

val to_dyn : (_, _) t -> Dyn.t

val create
  :  ('exe, 'lib) Package.Typed.t
  -> Build_dir.t
  -> Build_config.t
  -> ('exe, 'lib) t

val build_plan : (_, _) t -> op:Op.t -> Build_plan.t
val plan_exe : (true_t, _) t -> Build_plan.t
val plan_lib : (_, true_t) t -> Build_plan.t
val plan_lsp : (_, true_t) t -> Build_plan.t
val dot : (_, _) t -> string
