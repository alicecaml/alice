open! Alice_stdlib

(** Make a new directory in the system's temporary directory returning its
    path. Does not attempt to clean up after itself. *)
val mkdir : prefix:string -> suffix:string -> Filename.t

(** Make a new directory in the system's temporary directory calling [f] on its
    path, returning the result of [f] and deleting the temporary directory
    after [f] returns. *)
val with_ : prefix:string -> suffix:string -> f:(Filename.t -> 'a) -> 'a
