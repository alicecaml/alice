open! Alice_stdlib
open Alice_hierarchy

(** Make a new directory in the system's temporary directory returning its
    path. Does not attempt to clean up after itself. *)
val mkdir : prefix:string -> suffix:string -> Absolute_path.non_root_t

(** Make a new directory in the system's temporary directory calling [f] on its
    path, returning the result of [f] and deleting the temporary directory
    after [f] returns. *)
val with_ : prefix:string -> suffix:string -> f:(Absolute_path.non_root_t -> 'a) -> 'a
