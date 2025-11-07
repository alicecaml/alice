open! Alice_stdlib
open Alice_error

(** A version number following the semantic versioning spec
    (https://semver.org/) *)
type t

val to_dyn : t -> Dyn.t
val equal : t -> t -> bool
val compare : t -> t -> int
val to_string : t -> string

(** The version number with a leading "v" *)
val to_string_v : t -> string

val pre_release_string : t -> string option
val metadata_string : t -> string option

(** Returns an error if the argument isn't a valid semantic version. *)
val of_string : string -> t user_result

(** Raises a user error if the argument isn't a valid semantic version. *)
val of_string_exn : string -> t

(** Compares according to the semver precedence rules which ignore metadata. *)
val compare_for_precedence : t -> t -> int
