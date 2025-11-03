open! Alice_stdlib
open Alice_package
open Alice_hierarchy
open Type_bool

module Build_plan : sig
  type t

  val deps : t -> t list
  val op : t -> Typed_op.t
  val source_input : t -> Absolute_path.non_root_t option
  val compiled_inputs : t -> Typed_op.Generated_file.Compiled.t list
  val outputs : t -> Typed_op.Generated_file.Set.t
end

(** A DAG that knows how to build a collection of interdependent files and the
    dependencies between each file. *)
type ('exe, 'lib) t

val to_dyn : (_, _) t -> Dyn.t

val create
  :  ('exe, 'lib) Package.Typed.t
  -> Build_dir.t
  -> Alice_env.Os_type.t
  -> Alice_which.Ocamlopt.t
  -> ('exe, 'lib) t

val plan_exe : (true_t, _) t -> Build_plan.t
val plan_lib : (_, true_t) t -> Build_plan.t

val create_exe_plan
  :  (true_t, _) Package.Typed.t
  -> Build_dir.t
  -> Alice_env.Os_type.t
  -> Alice_which.Ocamlopt.t
  -> Build_plan.t

val create_lib_plan
  :  (_, true_t) Package.Typed.t
  -> Build_dir.t
  -> Alice_env.Os_type.t
  -> Alice_which.Ocamlopt.t
  -> Build_plan.t

val dot : (_, _) t -> string
