include module type of Stdlib.Filename

type t = string

val to_dyn : t -> Dyn.t

module Set : Set.S with type elt = t
module Map : Map.S with type key = t

val equal : t -> t -> bool
val compare : t -> t -> int
val has_extension : t -> ext:string -> bool

(** Returns [None] if the path doesn't have an extension. *)
val replace_extension : t -> ext:string -> t option

val add_extension : t -> ext:string -> t

module Components : sig
  type nonrec t =
    | Relative of t list
    | Absolute of
        { root : t
        ; rest : t list
        }
end

(** Split a path into the sequence of names that make it up. The sequence of
    components will never be empty, either begining with the filesystem root or
    the current directory. *)
val to_components : t -> Components.t

(** The two paths are made up of equal components, even if they differ on their
    path separators. *)
val equal_components : t -> t -> bool

val chop_prefix_opt : prefix:t -> t -> t option
val chop_prefix : prefix:t -> t -> t

(** Is this a filesystem root. On unix this is true only for the system's root
    directory. On windows this is true for the root of any drive. *)
val is_root : t -> bool

val normalize : t -> (t, [ `Would_traverse_beyond_the_start_of_absolute_path ]) result
