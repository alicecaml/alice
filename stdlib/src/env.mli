type t

(** Array of "<variable>=<value>" pairs *)
type raw = string array

val empty : t
val equal : t -> t -> bool
val to_dyn : t -> Dyn.t
val of_raw : raw -> t
val to_raw : t -> raw

(** Return the value of a variable if it is defined. *)
val get_opt : t -> name:string -> string option

(** Return the value of a variable if its name matches the predicate [f]. *)
val find_by_name_opt : t -> f:(string -> bool) -> string option

(** Return the name of a variable if its name matches the predicate [f]. *)
val find_name_opt : t -> f:(string -> bool) -> string option

val set : t -> name:string -> value:string -> t
