open! Spice_stdlib

module Dir : sig
  include module type of Spice_hierarchy.Dir

  val read : dir_path:Filename.t -> t
end
