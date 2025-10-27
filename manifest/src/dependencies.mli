open! Alice_stdlib
include module type of Alice_package_meta.Dependencies

val of_toml : manifest_path_for_messages:_ Alice_hierarchy.Path.t -> Toml.Types.table -> t
val to_toml : t -> Toml.Types.table
