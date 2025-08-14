open! Alice_stdlib

val parse_field_opt
  :  manifest_path_for_messages:_ Alice_hierarchy.Path.t
  -> Toml.Types.Table.Key.t
  -> Toml.Types.table
  -> f:(Toml.Types.value -> [ `Ok of 'a | `Expected of string ])
  -> 'a option

val parse_field
  :  manifest_path_for_messages:_ Alice_hierarchy.Path.t
  -> Toml.Types.Table.Key.t
  -> Toml.Types.table
  -> f:(Toml.Types.value -> [ `Ok of 'a | `Expected of string ])
  -> 'a

val check_for_extraneous_fields
  :  manifest_path_for_messages:_ Alice_hierarchy.Path.t
  -> all_keys:Toml.Types.Table.Key.t list
  -> Toml.Types.table
  -> unit
