open! Alice_stdlib
open Alice_package
include module type of Package_id

val of_toml : manifest_path_for_messages:_ Alice_hierarchy.Path.t -> Toml.Types.table -> t
val to_toml : t -> Toml.Types.table
