open! Alice_stdlib
open Alice_hierarchy

val manifest_name : Basename.t
val read_package_dir : dir_path:_ Absolute_path.t -> Package.t
val read_package_manifest : manifest_path:Absolute_path.non_root_t -> Package.t
val write_package_manifest : manifest_path:Absolute_path.non_root_t -> Package.t -> unit
