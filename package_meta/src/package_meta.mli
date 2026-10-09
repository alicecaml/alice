open! Alice_stdlib

type t

val to_dyn : t -> Dyn.t
val equal : t -> t -> bool

(** The [dependencies] and [unix] arguments are optional so that manifests that
    explicitly specify their default values can be distinguished from manifests
    that omit them when round-tripping. *)
val create
  :  id:Package_id.t
  -> dependencies:Dependencies.t option
  -> unix:bool option
  -> t

val id : t -> Package_id.t
val name : t -> Package_name.t
val version : t -> Semantic_version.t
val dependencies : t -> Dependencies.t

(** Like [dependencies] but exposes the optional value passed to [create]. Use
    this when serializing a [t] to round-trip. *)
val dependencies_ : t -> Dependencies.t option

(** The package needs access to the [Unix] module. *)
val unix : t -> bool

(** Like [unix] but exposes the optional value passed to [create]. Use
    this when serializing a [t] to round-trip. *)
val unix_ : t -> bool option
