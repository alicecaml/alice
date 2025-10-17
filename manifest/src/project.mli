open! Alice_stdlib

type t =
  { package : Package.t
  ; dependencies : Dependencies.t option
    (** This is an [_ option] so that a manifest with an empty dependencies
        list and a manifest with no dependencies list can both round trip via
        this type. *)
  }

val to_dyn : t -> Dyn.t
val of_toml : manifest_path_for_messages:_ Alice_hierarchy.Path.t -> Toml.Types.table -> t
val to_toml : t -> Toml.Types.table
val to_toml_string : t -> string

(** Returns the value of the [dependencies] field or an empty [Dependencies.t]
    if it is [None]. *)
val dependencies : t -> Dependencies.t
