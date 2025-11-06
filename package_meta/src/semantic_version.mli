open! Alice_stdlib
open Alice_error

(** A version number following the semantic versioning spec
    (https://semver.org/) *)
type t

val to_dyn : t -> Dyn.t
val equal : t -> t -> bool
val compare : t -> t -> int
val to_string : t -> string
val to_string_v : t -> string
val of_string : string -> t user_result

(** Raises a user error *)
val of_string_exn : string -> t
