open! Alice_stdlib
open Alice_hierarchy
open Alice_ocaml_toolchain
open Alice_package

module Out_dir : sig
  (** A directory in a package's base direrctory inside the build directory *)
  type t =
    | Private
    | Private_c
    | Public
    | Public_for_lsp
    | Generated_src
    | Executable
end

module Src_file : sig
  (** A file in the src directory *)
  type t

  val of_path
    :  Absolute_path.non_root_t
    -> ([ `Ml of t | `Mli of t | `C of t ], [ `Unknown_extension of string ]) result

  val of_path_ml : Absolute_path.non_root_t -> t
  val of_path_mli : Absolute_path.non_root_t -> t
  val of_path_c : Absolute_path.non_root_t -> t
  val to_path_ml : t -> Absolute_path.non_root_t
  val to_path_mli : t -> Absolute_path.non_root_t
  val to_path_c : t -> Absolute_path.non_root_t
end

module Gen_file : sig
  (** A file in a package base directory inside the build directory *)
  type t

  module Set : Set.S with type elt = t
  module Map : Map.S with type key = t

  val to_dyn : t -> Dyn.t
  val equal : t -> t -> bool
  val path : t -> Basename.t
  val out_dir : t -> Out_dir.t
  val compiled_ocaml_object_file : Basename.t -> t
  val compiled_ocaml_interface_file : Basename.t -> t
  val compiled_c_object_file : Basename.t -> t
  val lib_ocaml_object_file : Compiler_backend.t -> t
  val lib_ocaml_archive_file : Compiler_backend.t -> t
  val lib_ocaml_compiled_interface_file : t
  val exe_ocaml_object_file : Compiler_backend.t -> t
  val generated_ocaml_src_file : Basename.t -> t
  val executable : Basename.t -> t

  (** An OCaml object file to specify as an output to the compiler when
      generating a library's top-level .cmt file which merlin/ocamllsp will
      consume. The specified object file will actually be generated because the
      compiler will be run with `-stop-after typing` to save time, but we still
      pass the name of the object file that would be generated so files that do
      get generated (namely a .cmt and .cmi file) are named appropriately. *)
  val compiled_ocaml_object_to_generate_library_lsp_files
    :  Package_name.t
    -> Compiler_backend.t
    -> t

  (** Interface file that will be generated alongside the .cmt file when
      generating inputs for merlin/ocamllsp *)
  val compiled_ocaml_interface_to_generate_library_lsp_files : Package_name.t -> t
end

module Pack : sig
  type t

  val equal : t -> t -> bool
  val of_package_name : Alice_package.Package_name.t -> t
  val package_name : t -> Alice_package.Package_name.t
  val compiled_ocaml_object_file : t -> Gen_file.t
  val module_name : t -> Module_name.t
end

module Compile_ocaml_source : sig
  type t =
    { source_input : Src_file.t
    ; compiled_inputs : Gen_file.t list
    ; compiled_object_output : Gen_file.t
    ; interface_output_if_no_matching_mli_is_present : Gen_file.t option
    ; stop_after_typing : bool
    }

  val to_dyn : t -> Dyn.t
end

module Compile_ocaml_interface : sig
  type t =
    { interface_input : Src_file.t
    ; compiled_inputs : Gen_file.t list
    ; compiled_interface_output : Gen_file.t
    ; stop_after_typing : bool
    }

  val to_dyn : t -> Dyn.t
end

module Compile_c_source : sig
  type t =
    { source_input : Src_file.t
    ; object_output : Gen_file.t
    }

  val to_dyn : t -> Dyn.t
end

module Pack_library : sig
  type t =
    { compiled_object_inputs : Gen_file.t list
    ; pack : Pack.t
    }
end

module Generate_public_interface_to_open : sig
  type t = { ml_output : Gen_file.t }
end

module Compile_public_interface_to_open : sig
  type t =
    { generated_source_input : Gen_file.t
    ; internal_modules_pack : Pack.t
    ; compiled_object_output : Gen_file.t
    ; compiled_interface_output : Gen_file.t
    }

  val create : generated_source_input:Gen_file.t -> internal_modules_pack:Pack.t -> t
end

module Link_library : sig
  type t =
    { compiled_object_inputs : Gen_file.t list
    ; compiled_c_inputs : Gen_file.t list
    ; ocaml_archive_output : Gen_file.t
    ; archive_output : Gen_file.t
    }

  val of_inputs
    :  compiled_object_inputs:Gen_file.t list
    -> compiled_c_inputs:Gen_file.t list
    -> t
end

module Link_executable : sig
  type t =
    { compiled_object_inputs : Gen_file.t list
    ; compiled_c_inputs : Gen_file.t list
    ; exe_output : Gen_file.t
    }
end

type t =
  | Compile_ocaml_source of Compile_ocaml_source.t
  | Compile_ocaml_interface of Compile_ocaml_interface.t
  | Compile_c_source of Compile_c_source.t
  | Pack_library of Pack_library.t
  | Generate_public_interface_to_open of Generate_public_interface_to_open.t
  | Compile_public_interface_to_open of Compile_public_interface_to_open.t
  | Link_library of Link_library.t
  | Link_executable of Link_executable.t

val equal : t -> t -> bool
val to_dyn : t -> Dyn.t
val source_input : t -> Absolute_path.non_root_t option
val generated_inputs : t -> Gen_file.t list
val outputs : t -> Gen_file.t list

module Set : Set.S with type elt = t
module Map : Map.S with type key = t
