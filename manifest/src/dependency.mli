open! Alice_stdlib
open Alice_hierarchy

(** A single entry in a package's list of dependencies. *)
type t =
  { name : Package_name.t
  ; path : Path.Either.t
    (** The path to the directory where the package is defined. The package in
        this directory must be named the same as the [name] field. 

        TODO: Eventually more ways of specifying a package will be added at
              which point this will become a variant.
        *)
  }

val to_dyn : t -> Dyn.t

val of_toml
  :  manifest_path_for_messages:_ Alice_hierarchy.Path.t
  -> name:Package_name.t
  -> Toml.Types.value
  -> t

val to_toml : t -> Toml.Types.Table.Key.t * Toml.Types.value
