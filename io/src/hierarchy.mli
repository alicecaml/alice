open! Alice_stdlib
include module type of Alice_hierarchy

module File : sig
  include module type of File

  val read : Filename.t -> (t, [ `Not_found ]) result
end
