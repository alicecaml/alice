open! Alice_stdlib
include module type of Alice_package_meta.Package_meta

val to_dyn : t -> Dyn.t

val of_toml
  :  manifest_path_for_messages:Alice_hierarchy.Absolute_path.non_root_t
  -> Toml.Types.table
  -> t

val to_toml : t -> Toml.Types.table
val of_kdl_node : Kdl.node -> unit
