open! Alice_stdlib
open Alice_hierarchy

val make : prefix:string -> suffix:string -> Absolute_path.non_root_t

(** Make a new directory in the system's temporary directory calling [f] on its
    path, returning the result of [f] and deleting the temporary directory
    after [f] returns. If [keep] is true then don't delete the directory
    afterwards. *)
val with_
  :  prefix:string
  -> suffix:string
  -> keep:bool
  -> f:(Absolute_path.non_root_t -> 'a)
  -> 'a
