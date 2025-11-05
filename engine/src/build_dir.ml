open! Alice_stdlib
open Alice_hierarchy
open Alice_package

type t = { path : Absolute_path.non_root_t }

let of_path path = { path }
let path { path } = path

let package_dir t package_id =
  t.path
  / Basename.of_filename "packages"
  / Basename.of_filename (Package_id.name_dash_version_string package_id)
;;

let package_ocamldeps_cache_file t package_id =
  package_dir t package_id / Basename.of_filename "ocamldeps_cache.marshal"
;;

let package_base_dir t package_id profile =
  package_dir t package_id / Basename.of_filename (Profile.name profile)
;;

let package_private_dir t package_id profile =
  package_base_dir t package_id profile / Basename.of_filename "private"
;;

let package_public_dir t package_id profile =
  package_base_dir t package_id profile / Basename.of_filename "public"
;;

let package_executable_dir t package_id profile =
  package_base_dir t package_id profile / Basename.of_filename "executable"
;;

let package_dirs t package_id profile =
  [ package_public_dir t package_id profile
  ; package_private_dir t package_id profile
  ; package_executable_dir t package_id profile
  ]
;;

let package_generated_file_compiled t package_id profile compiled =
  let open Typed_op.Generated_file in
  let base =
    match Compiled.visibility compiled with
    | Private -> package_private_dir t package_id profile
    | Public -> package_public_dir t package_id profile
  in
  base / Compiled.path compiled
;;

let package_generated_file t package_id profile generated_file =
  let open Typed_op.Generated_file in
  match (generated_file : t) with
  | Compiled compiled -> package_generated_file_compiled t package_id profile compiled
  | Linked_library linked_library ->
    package_public_dir t package_id profile / Linked_library.path linked_library
  | Linked_executable path -> package_executable_dir t package_id profile / path
;;
