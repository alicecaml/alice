open! Alice_stdlib

module File : sig
  type t = Alice_hierarchy.File.t
  type kind = Alice_hierarchy.File.kind
  type dir = Alice_hierarchy.File.dir

  val read : Filename.t -> (t, [ `Not_found ]) result
  val to_dyn : t -> Dyn.t
  val as_dir : t -> dir option
  val is_dir : t -> bool
  val is_regular_or_link : t -> bool
  val traverse_bottom_up : t -> f:(t -> unit) -> unit
  val traverse_top_down : t -> f:(t -> unit) -> unit
end

module Dir = Alice_hierarchy.Dir
