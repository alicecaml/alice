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

let package_internal_dir t package_id profile =
  package_base_dir t package_id profile / Basename.of_filename "internal"
;;

let package_lib_dir t package_id profile =
  package_base_dir t package_id profile / Basename.of_filename "lib"
;;

let package_exe_dir t package_id profile =
  package_base_dir t package_id profile / Basename.of_filename "exe"
;;

let package_dirs t package_id profile =
  [ package_internal_dir t package_id profile
  ; package_lib_dir t package_id profile
  ; package_exe_dir t package_id profile
  ]
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
