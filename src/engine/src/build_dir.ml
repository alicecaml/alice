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

module Package_base_dir = struct
  type nonrec t =
    { build_dir : t
    ; path : Absolute_path.non_root_t
    }

  let build_dir { build_dir; _ } = build_dir
  let generated_source_dir t = t.path / b "generated"
  let private_dir t = t.path / b "private"

  (* Directory for containing the object files compiled from C code in the src
   directory. This is separate from the "private" directory because otherwise a
   C source file with the same name as an OCaml source file (besides the
   extension) would collide in their compiled object file. *)
  let private_c_dir t = t.path / b "private_c"
  let public_dir t = t.path / b "public"
  let public_for_lsp_dir t = t.path / b "public_for_lsp"
  let executable_dir t = t.path / b "executable"

  let dirs t =
    [ generated_source_dir t
    ; public_dir t
    ; public_for_lsp_dir t
    ; private_dir t
    ; private_c_dir t
    ; executable_dir t
    ]
  ;;

  let generated_file_compiled t compiled =
    let open Typed_op.Generated_file in
    let base =
      match Compiled.visibility compiled with
      | Private -> private_dir t
      | Private_c -> private_c_dir t
      | Public -> public_dir t
      | Public_for_lsp -> public_for_lsp_dir t
    in
    base / Compiled.path compiled
  ;;

  let generated_file t generated_file =
    let open Typed_op.Generated_file in
    match (generated_file : t) with
    | Generated_ocaml_source path -> generated_source_dir t / path
    | Compiled compiled -> generated_file_compiled t compiled
    | Linked_library linked_library -> public_dir t / Linked_library.path linked_library
    | Linked_executable linked_executable ->
      executable_dir t / Linked_executable.path linked_executable
  ;;

  let gen_file t gen_file =
    let open Typed_op in
    let base =
      match Gen_file.visibility gen_file with
      | Private -> private_dir t
      | Private_c -> private_c_dir t
      | Public -> public_dir t
      | Public_for_lsp -> public_for_lsp_dir t
    in
    base / Gen_file.path gen_file
  ;;
end

let package_base_dir t package_id compiler_backend profile =
  { Package_base_dir.build_dir = t
  ; path =
      package_dir t package_id
      / b (Compiler_backend.name compiler_backend)
      / b (Profile.name profile)
  }
;;

let package_base_dir_of_build_config t package_id (build_config : Build_config.t) =
  package_base_dir t package_id build_config.compiler_backend build_config.profile
;;
