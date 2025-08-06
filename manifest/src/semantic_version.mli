open! Alice_stdlib

(** A version number following the semantic versioning spec
    (https://semver.org/) *)
type t

val to_dyn : t -> Dyn.t
val to_string : t -> string
val of_string_res : string -> (t, Ansi_style.t Pp.t list) result
val of_string : string -> t
