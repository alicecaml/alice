open! Alice_stdlib
module Builtin_module = Alice_builtin_module

type t

val to_dyn : t -> Dyn.t
val equal : t -> t -> bool

val create
  :  id:Package_id.t
  -> dependencies:Dependencies.t
  -> builtin_modules:Builtin_module.Set.t
  -> t

val id : t -> Package_id.t
val name : t -> Package_name.t
val version : t -> Semantic_version.t
val dependencies : t -> Dependencies.t
val builtin_modules : t -> Builtin_module.Set.t
