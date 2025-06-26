open! Alice_stdlib

(** Make a new directory in the system's temporary directory returning its
    path. Does not attempt to clean up after itself. *)
val mkdir : prefix:string -> suffix:string -> Filename.t
