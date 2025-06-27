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

  module Dir : sig
    type nonrec t =
      { path : Filename.t
      ; contents : t list
      }
  end

  val as_dir : t -> Dir.t option
  val is_regular_or_link : t -> bool
  val traverse_bottom_up : t -> f:(t -> unit) -> unit
end
