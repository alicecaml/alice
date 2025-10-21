open! Alice_stdlib

type t

val to_dyn : t -> Dyn.t
val equal : t -> t -> bool

(** The [dependencies] argument is optional so that the presence of an empty
    dependencies list can be distinguished from a lack af a dependencies list
    so that a package manifest can be round tripped via [t]. *)
val create : id:Package_id.t -> dependencies:Dependencies.t option -> t

val id : t -> Package_id.t
val name : t -> Package_name.t
val version : t -> Semantic_version.t
val dependencies : t -> Dependencies.t

(** Like [dependencies] but exposes the optional value passed to [create]. Use
    this when serializing a [t] to round-trip. *)
val dependencies_ : t -> Dependencies.t option
