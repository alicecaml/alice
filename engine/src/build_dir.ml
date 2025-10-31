open! Alice_stdlib
open Alice_hierarchy
open Alice_package

type t = { path : Path.Absolute.t }

let of_path path = { path }
let path { path } = path

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

let package_internal_dir t package_id profile =
  package_artifacts_dir t package_id profile / Path.relative "internal"
;;

let package_lib_dir t package_id profile =
  package_artifacts_dir t package_id profile / Path.relative "lib"
;;

let package_exe_dir t package_id profile =
  package_artifacts_dir t package_id profile / Path.relative "exe"
;;

let package_role_dir t package_id profile role =
  let f =
    match (role : Typed_op.Role.t) with
    | Internal -> package_internal_dir
    | Lib -> package_lib_dir
    | Exe -> package_exe_dir
  in
  f t package_id profile
;;

let package_generated_file t package_id profile generated_file =
  match (generated_file : Typed_op.Generated_file.t) with
  | Compiled { path; role } -> package_role_dir t package_id profile role / path
  | Linked_library linked_library ->
    package_lib_dir t package_id profile
    / Typed_op.Generated_file.Linked_library.path linked_library
  | Linked_executable path -> package_exe_dir t package_id profile / path
;;
