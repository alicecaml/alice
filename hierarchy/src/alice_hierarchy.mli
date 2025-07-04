open! Alice_stdlib

module File : sig
  type kind =
    | Regular
    | Link of Filename.t
    | Dir of t list
    | Unknown

  and t =
    { path : Filename.t
    ; kind : kind
    }

  type dir =
    { path : Filename.t
    ; contents : t list
    }

  val to_dyn : t -> Dyn.t
  val as_dir : t -> dir option
  val is_dir : t -> bool
  val is_regular_or_link : t -> bool
  val traverse_bottom_up : t -> f:(t -> unit) -> unit
  val traverse_top_down : t -> f:(t -> unit) -> unit
end

module Dir : sig
  type t = File.dir =
    { path : Filename.t
    ; contents : File.t list
    }

  val to_dyn : t -> Dyn.t
end
