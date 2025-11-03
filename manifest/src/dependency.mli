open! Alice_stdlib
open Alice_package_meta
include module type of Dependency

val of_toml
  :  manifest_path_for_messages:Alice_hierarchy.Absolute_path.non_root_t
  -> name:Package_name.t
  -> Toml.Types.value
  -> t

val to_toml : t -> Toml.Types.Table.Key.t * Toml.Types.value
