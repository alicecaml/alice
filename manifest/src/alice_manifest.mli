open! Alice_stdlib
open Alice_hierarchy
open Alice_package_meta

val manifest_name : string
val read_package_dir : dir_path:_ Path.t -> Package.t
val read_package_manifest : manifest_path:_ Path.t -> Package.t
val write_package_manifest : manifest_path:_ Path.t -> Package.t -> unit
