open! Alice_stdlib

type t

val to_dyn : t -> Dyn.t
val equal : t -> t -> bool
val create : id:Package_id.t -> dependencies:Dependencies.t -> unix:bool -> t
val id : t -> Package_id.t
val name : t -> Package_name.t
val version : t -> Semantic_version.t
val dependencies : t -> Dependencies.t

(** The package needs access to the [Unix] module. *)
val unix : t -> bool
