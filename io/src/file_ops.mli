open! Alice_stdlib

val rm_rf : Filename.t -> unit
val mkdir_p : Filename.t -> unit

(** [src] and [dst] must be paths to existing directories. Each file under
    [src] is moved (renamed) to the same relative path under [dst], creating
    intermediate directories as needed. The existing directory structure under
    [dst] is replaced, though files will be replaced if they are at the same
    location as a correspondingly-named file under [src]. *)
val recursive_move_between_dirs : src:Filename.t -> dst:Filename.t -> unit
