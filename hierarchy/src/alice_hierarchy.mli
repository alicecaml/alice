open! Alice_stdlib

module Path : sig
  type absolute
  type relative
  type 'kind t
  type 'a with_path = { f : 'kind. 'kind t -> 'a }

  module Absolute : sig
    type nonrec t = absolute t

    val getcwd : unit -> t
  end

  module Relative : sig
    type nonrec t = relative t

    val to_absolute : cwd:Absolute.t -> t -> Absolute.t
  end

  module Either : sig
    type t =
      [ `Absolute of Absolute.t
      | `Relative of Relative.t
      ]

    val with_ : t -> f:'a with_path -> 'a
    val to_absolute : cwd:Absolute.t -> t -> Absolute.t
  end

  val of_filename : Filename.t -> Either.t
  val with_filename : Filename.t -> f:'a with_path -> 'a
  val absolute : Filename.t -> absolute t
  val relative : Filename.t -> relative t
  val concat : 'a t -> relative t -> 'a t
  val chop_prefix_opt : prefix:'a t -> 'a t -> relative t option
  val chop_prefix : prefix:'a t -> 'a t -> relative t
  val to_filename : _ t -> Filename.t
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

  val to_dyn : _ t -> Dyn.t
  val as_dir : 'path_kind t -> 'path_kind dir option
  val is_dir : _ t -> bool
  val is_regular_or_link : _ t -> bool
  val traverse_bottom_up : 'path_kind t -> f:('path_kind t -> unit) -> unit
end

module Dir : sig
  type 'path_kind t = 'path_kind File.dir =
    { path : 'path_kind Path.t
    ; contents : 'path_kind File.t list
    }

  val to_dyn : _ t -> Dyn.t
end
