open! Alice_stdlib
open Alice_hierarchy

module Env : sig
  type t
  type raw = string array

  val to_dyn : t -> Dyn.t
  val current : unit -> t
  val of_raw : raw -> t
  val to_raw : t -> raw
  val set : t -> name:string -> value:string -> t
end

module Path_variable : sig
  type t = Path.Absolute.t list

  val to_dyn : t -> Dyn.t
  val get_or_empty : ?name:string -> Env.t -> t

  val get_result
    :  ?name:string
    -> Env.t
    -> (t, [ `Variable_not_defined of string ]) result

  val set : ?name:string -> t -> Env.t -> Env.t
end

val initial_cwd : Path.Absolute.t
