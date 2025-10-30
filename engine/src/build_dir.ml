open! Alice_stdlib
open Alice_hierarchy
open Alice_package

type t = { path : Path.Absolute.t }

let of_path path = { path }

let package_dir t package_id =
  t.path
  / Path.relative "packages"
  / Path.relative (Package_id.name_dash_version_string package_id)
;;

let package_ocamldeps_cache_file t package_id =
  package_dir t package_id / Path.relative "ocamldeps_cache.marshal"
;;

let package_artifacts_dir t package_id profile =
  package_dir t package_id / Path.relative (Profile.name profile)
;;
