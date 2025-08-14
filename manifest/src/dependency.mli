open! Alice_stdlib

type t =
  { name : Package_name.t
  ; version_pattern : Version_pattern.t
  }

val to_dyn : t -> Dyn.t

val of_toml
  :  manifest_path_for_messages:_ Alice_hierarchy.Path.t
  -> name:Package_name.t
  -> Toml.Types.value
  -> t

val to_toml_except_name : t -> Toml.Types.value
