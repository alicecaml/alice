open! Alice_stdlib
open Alice_hierarchy

val rm_rf : _ Path.t -> unit
val mkdir_p : _ Path.t -> unit

(** [src] and [dst] must be paths to existing directories. Each file under
    [src] is moved (renamed) to the same relative path under [dst], creating
    intermediate directories as needed. The existing directory structure under
    [dst] is replaced, though files will be replaced if they are at the same
    location as a correspondingly-named file under [src]. *)
val recursive_move_between_dirs : src:_ Path.t -> dst:_ Path.t -> unit
