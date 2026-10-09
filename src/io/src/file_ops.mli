open! Alice_stdlib
open Alice_hierarchy

val rm_rf : Absolute_path.non_root_t -> unit
val mkdir_p : _ Absolute_path.t -> unit

(** [src] and [dst] must be paths to existing directories. Each file under
    [src] is moved (renamed) to the same relative path under [dst], creating
    intermediate directories as needed. The existing directory structure under
    [dst] is replaced, though files will be replaced if they are at the same
    location as a correspondingly-named file under [src]. *)
val recursive_move_between_dirs
  :  src:Absolute_path.non_root_t
  -> dst:_ Absolute_path.t
  -> unit

val cp_rf : src:Absolute_path.non_root_t -> dst:_ Absolute_path.t -> unit
val cp_f : src:Absolute_path.non_root_t -> dst:_ Absolute_path.t -> unit
val exists : _ Absolute_path.t -> bool
val is_directory : _ Absolute_path.t -> bool

val with_out_channel
  :  Absolute_path.non_root_t
  -> mode:[ `Text | `Bin ]
  -> f:(out_channel -> 'a)
  -> 'a

val write_text_file : Absolute_path.non_root_t -> string -> unit

val with_in_channel
  :  Absolute_path.non_root_t
  -> mode:[ `Text | `Bin ]
  -> f:(in_channel -> 'a)
  -> 'a

val read_text_file : Absolute_path.non_root_t -> string
val mtime : Absolute_path.non_root_t -> float
val symlink : src:Absolute_path.non_root_t -> dst:Absolute_path.non_root_t -> unit
