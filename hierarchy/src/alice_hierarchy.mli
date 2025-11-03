open! Alice_stdlib

module Basename : sig
  (** The name of a file, with preceeding path components. This is similar to
      the output of the "basename" unix command, however the filesystem root
      directory is not considered to be a basename. *)
  type t

  val to_dyn : t -> Dyn.t
  val equal : t -> t -> bool

  (** Panics if the given filename is not a valid basename. *)
  val of_filename : Filename.t -> t

  val to_filename : t -> Filename.t
  val compare : t -> t -> int
  val extension : t -> string
  val has_extension : t -> ext:string -> bool
  val replace_extension : t -> ext:string -> t
  val add_extension : t -> ext:string -> t
  val remove_extension : t -> t
end

module Relative_path : sig
  type t

  val to_dyn : t -> Dyn.t
  val equal : t -> t -> bool
  val of_basename : Basename.t -> t

  (** Panics if the given filename is not a relative path. *)
  val of_filename : Filename.t -> t

  val to_filename : t -> Filename.t
end

module Absolute_path : sig
  (** An absolute path with a type parameter which determines whether the path
      is the filesystem root directory or not. *)
  type 'is_root t

  type root_t = Type_bool.true_t t
  type non_root_t = Type_bool.false_t t

  module Root_or_non_root : sig
    type t =
      [ `Root of root_t
      | `Non_root of non_root_t
      ]

    val to_dyn : t -> Dyn.t
    val equal : t -> t -> bool
    val assert_non_root : t -> non_root_t
    val to_filename : t -> Filename.t
    val concat_relative : t -> Relative_path.t -> non_root_t
    val concat_basename : t -> Basename.t -> non_root_t
  end

  module Non_root_map : Map.S with type key = non_root_t

  val to_dyn : _ t -> Dyn.t
  val equal : 'a t -> 'a t -> bool

  (** Panics if the given filename is not an absolute path. *)
  val of_filename : Filename.t -> Root_or_non_root.t

  val of_filename_assert_non_root : Filename.t -> non_root_t
  val to_filename : _ t -> Filename.t
  val concat_relative : _ t -> Relative_path.t -> non_root_t
  val concat_basename : _ t -> Basename.t -> non_root_t
  val compare : 'a t -> 'a t -> int
  val extension : non_root_t -> string
  val has_extension : non_root_t -> ext:string -> bool
  val replace_extension : non_root_t -> ext:string -> non_root_t
  val add_extension : non_root_t -> ext:string -> non_root_t
  val remove_extension : non_root_t -> non_root_t
  val parent : non_root_t -> Root_or_non_root.t
  val basename : non_root_t -> Basename.t
  val is_root : 'is_root t -> 'is_root Type_bool.t
end

module Either_path : sig
  type t =
    [ `Absolute of Absolute_path.Root_or_non_root.t
    | `Relative of Relative_path.t
    ]

  val to_dyn : t -> Dyn.t
  val equal : t -> t -> bool
  val of_filename : Filename.t -> t
  val to_filename : t -> Filename.t
end

module File_non_root : sig
  type kind =
    | Regular
    | Link
    | Dir of t list
    | Unknown

  and t =
    { path : Absolute_path.non_root_t
    ; kind : kind
    }

  type dir =
    { path : Absolute_path.non_root_t
    ; contents : t list
    }

  val path : t -> Absolute_path.non_root_t
  val kind : t -> kind
  val to_dyn : t -> Dyn.t
  val as_dir : t -> dir option
  val is_dir : t -> bool
  val is_regular_or_link : t -> bool
  val traverse_bottom_up : t -> f:(t -> unit) -> unit
  val map_paths : t -> f:(Absolute_path.non_root_t -> Absolute_path.non_root_t) -> t
  val compare_by_path : t -> t -> int
end

module Dir_non_root : sig
  type t = File_non_root.dir =
    { path : Absolute_path.non_root_t
    ; contents : File_non_root.t list
    }

  val to_dyn : t -> Dyn.t
  val path : t -> Absolute_path.non_root_t
  val contents : t -> File_non_root.t list
  val contains : t -> Absolute_path.non_root_t -> bool
end

(** Infix [Absolute_path.concat_basename] operator *)
val ( / ) : _ Absolute_path.t -> Basename.t -> Absolute_path.non_root_t
