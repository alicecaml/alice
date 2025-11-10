open! Alice_stdlib
open Alice_hierarchy

val initial_cwd : Absolute_path.Root_or_non_root.t
val current_env : unit -> Env.t

module Os_type : sig
  type t

  val current : unit -> t
  val is_windows : t -> bool
  val filename_add_exe_extension_on_windows : t -> Filename.t -> Filename.t
  val basename_add_exe_extension_on_windows : t -> Basename.t -> Basename.t
end

module Path_variable : sig
  type t = Absolute_path.Root_or_non_root.t list

  val to_dyn : t -> Dyn.t
  val get_or_empty : Os_type.t -> Env.t -> t
  val get_result : Os_type.t -> Env.t -> (t, [ `Variable_not_defined of string ]) result
  val set : t -> Os_type.t -> Env.t -> Env.t
end

module Xdg : sig
  include module type of Xdg

  val create : Os_type.t -> Env.t -> Xdg.t
end
