open! Alice_stdlib

module Dir : sig
  include module type of Alice_hierarchy.Dir

  val read : dir_path:Filename.t -> t
end
