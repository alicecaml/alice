open! Alice_stdlib
open Alice_hierarchy
open Alice_package
open Alice_ocaml_toolchain

type t = { path : Absolute_path.non_root_t }

let b = Basename.of_filename
let basename = b "build"

let of_project_root_path project_root_path =
  let path =
    match project_root_path with
    | `Root path -> path / basename
    | `Non_root path -> path / basename
  in
  { path }
;;

let path { path } = path

let package_dir t package_id =
  t.path / b "packages" / b (Package_id.name_dash_version_string package_id)
;;

let package_ocamldeps_cache_file t package_id compiler_backend =
  package_dir t package_id
  / b (Compiler_backend.name compiler_backend)
  / b "ocamldeps_cache.marshal"
;;

let package_base_dir t package_id compiler_backend profile =
  package_dir t package_id
  / b (Compiler_backend.name compiler_backend)
  / b (Profile.name profile)
;;

let package_generated_source_dir t package_id compiler_backend profile =
  package_base_dir t package_id compiler_backend profile / b "generated"
;;

let package_private_dir t package_id compiler_backend profile =
  package_base_dir t package_id compiler_backend profile / b "private"
;;

(* Directory for containing the object files compiled from C code in the src
   directory. This is separate from the "private" directory because otherwise a
   C source file with the same name as an OCaml source file (besides the
   extension) would collide in their compiled object file. *)
let package_private_c_dir t package_id compiler_backend profile =
  package_base_dir t package_id compiler_backend profile / b "private_c"
;;

let package_public_dir t package_id compiler_backend profile =
  package_base_dir t package_id compiler_backend profile / b "public"
;;

let package_public_for_lsp_dir t package_id compiler_backend profile =
  package_base_dir t package_id compiler_backend profile / b "public_for_lsp"
;;

let package_executable_dir t package_id compiler_backend profile =
  package_base_dir t package_id compiler_backend profile / b "executable"
;;

let package_dirs t package_id compiler_backend profile =
  [ package_generated_source_dir t package_id compiler_backend profile
  ; package_public_dir t package_id compiler_backend profile
  ; package_public_for_lsp_dir t package_id compiler_backend profile
  ; package_private_dir t package_id compiler_backend profile
  ; package_private_c_dir t package_id compiler_backend profile
  ; package_executable_dir t package_id compiler_backend profile
  ]
;;

let package_generated_file_compiled t package_id compiler_backend profile compiled =
  let open Typed_op.Generated_file in
  let base =
    match Compiled.visibility compiled with
    | Private -> package_private_dir t package_id compiler_backend profile
    | Private_c -> package_private_c_dir t package_id compiler_backend profile
    | Public -> package_public_dir t package_id compiler_backend profile
    | Public_for_lsp -> package_public_for_lsp_dir t package_id compiler_backend profile
  in
  base / Compiled.path compiled
;;

let package_generated_file t package_id compiler_backend profile generated_file =
  let open Typed_op.Generated_file in
  match (generated_file : t) with
  | Generated_ocaml_source path ->
    package_generated_source_dir t package_id compiler_backend profile / path
  | Compiled compiled ->
    package_generated_file_compiled t package_id compiler_backend profile compiled
  | Linked_library linked_library ->
    package_public_dir t package_id compiler_backend profile
    / Linked_library.path linked_library
  | Linked_executable path ->
    package_executable_dir t package_id compiler_backend profile / path
;;
