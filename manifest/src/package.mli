open! Alice_stdlib

type t = { name : Package_name.t }

val to_dyn : t -> Dyn.t
val of_toml : manifest_path_for_messages:_ Alice_hierarchy.Path.t -> Toml.Types.table -> t
val to_toml : t -> Toml.Types.table
