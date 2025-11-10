type t

(** Array of "<variable>=<value>" pairs *)
type raw = string array

val empty : t
val equal : t -> t -> bool
val to_dyn : t -> Dyn.t
val of_raw : raw -> t
val to_raw : t -> raw
val get_opt : t -> name:string -> string option
val find_name_opt : t -> f:(string -> bool) -> string option
val set : t -> name:string -> value:string -> t
