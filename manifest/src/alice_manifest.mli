open! Alice_stdlib
open Alice_hierarchy

val manifest_name : string
val read_package_dir : dir_path:Path.Absolute.t -> Package.t
val read_package_manifest : manifest_path:Path.Absolute.t -> Package.t
val write_package_manifest : manifest_path:Path.Absolute.t -> Package.t -> unit
