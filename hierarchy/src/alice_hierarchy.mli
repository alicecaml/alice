open! Alice_stdlib

module Path : sig
  type absolute
  type relative
  type 'kind t

  module Kind : sig
    type 'kind t

    val absolute : absolute t
    val relative : relative t
  end

  type 'a with_path = { f : 'kind. 'kind t -> 'a }

  module type S := sig
    type t

    val to_dyn : t -> Dyn.t
    val equal : t -> t -> bool
    val to_filename : t -> Filename.t
    val extension : t -> string
    val has_extension : t -> ext:string -> bool
    val replace_extension : t -> ext:string -> t

    module Set : Set.S with type elt = t
    module Map : Map.S with type key = t
  end

  val to_dyn : _ t -> Dyn.t

  module Absolute : sig
    include S with type t = absolute t
  end

  module Relative : sig
    include S with type t = relative t
  end

  module Either : sig
    type t =
      [ `Absolute of Absolute.t
      | `Relative of Relative.t
      ]

    val with_ : t -> f:'a with_path -> 'a
  end

  val to_filename : _ t -> Filename.t
  val of_filename : Filename.t -> Either.t
  val with_filename : Filename.t -> f:'a with_path -> 'a
  val absolute : Filename.t -> absolute t
  val relative : Filename.t -> relative t
  val kind : 'a t -> 'a Kind.t
  val of_filename_checked : 'a Kind.t -> Filename.t -> 'a t
  val current_dir : relative t
  val concat : 'a t -> relative t -> 'a t
  val chop_prefix_opt : prefix:'a t -> 'a t -> relative t option
  val chop_prefix : prefix:'a t -> 'a t -> relative t
  val equal : 'a t -> 'a t -> bool

  (** Returns the path's extension, including the starting period *)
  val extension : _ t -> string

  (** [ext] must include the starting period *)
  val has_extension : _ t -> ext:string -> bool

  (** [ext] must include the starting period *)
  val replace_extension : 'a t -> ext:string -> 'a t

  val match_ : 'a t -> absolute:(absolute t -> 'b) -> relative:(relative t -> 'b) -> 'b
end

module File : sig
  type 'path_kind kind =
    | Regular
    | Link
    | Dir of 'path_kind t list
    | Unknown

  and 'path_kind t =
    { path : 'path_kind Path.t
    ; kind : 'path_kind kind
    }

  type 'path_kind dir =
    { path : 'path_kind Path.t
    ; contents : 'path_kind t list
    }

  val path : 'a t -> 'a Path.t
  val kind : 'a t -> 'a kind
  val to_dyn : _ t -> Dyn.t
  val as_dir : 'path_kind t -> 'path_kind dir option
  val is_dir : _ t -> bool
  val is_regular_or_link : _ t -> bool
  val traverse_bottom_up : 'path_kind t -> f:('path_kind t -> unit) -> unit
  val map_paths : 'a t -> f:('a Path.t -> 'b Path.t) -> 'b t
end

module Dir : sig
  type 'path_kind t = 'path_kind File.dir =
    { path : 'path_kind Path.t
    ; contents : 'path_kind File.t list
    }

  val to_dyn : _ t -> Dyn.t
  val to_relative : _ t -> Path.relative t
  val path : 'a t -> 'a Path.t
  val contents : 'a t -> 'a File.t list
end
