open! Alice_stdlib
open Alice_hierarchy

val rm_rf : Path.Absolute.t -> unit
val mkdir_p : Path.Absolute.t -> unit

(** [src] and [dst] must be paths to existing directories. Each file under
    [src] is moved (renamed) to the same relative path under [dst], creating
    intermediate directories as needed. The existing directory structure under
    [dst] is replaced, though files will be replaced if they are at the same
    location as a correspondingly-named file under [src]. *)
val recursive_move_between_dirs : src:Path.Absolute.t -> dst:Path.Absolute.t -> unit

val cp_rf : src:Path.Absolute.t -> dst:Path.Absolute.t -> unit
val cp_f : src:Path.Absolute.t -> dst:Path.Absolute.t -> unit
val exists : _ Path.t -> bool
val is_directory : Path.Absolute.t -> bool

val with_out_channel
  :  Path.Absolute.t
  -> mode:[ `Text | `Bin ]
  -> f:(out_channel -> 'a)
  -> 'a

val write_text_file : Path.Absolute.t -> string -> unit

val with_in_channel
  :  Path.Absolute.t
  -> mode:[ `Text | `Bin ]
  -> f:(in_channel -> 'a)
  -> 'a

val read_text_file : Path.Absolute.t -> string
val mtime : Path.Absolute.t -> float
val symlink : src:Path.Absolute.t -> dst:Path.Absolute.t -> unit
