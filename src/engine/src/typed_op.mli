open! Alice_stdlib
open Alice_hierarchy
open Alice_ocaml_toolchain
open Alice_package

module Visibility : sig
  (** How a compiled file will be visible to other files during compilation.
      Note that this is orthogonal to OCaml's own visibility mechanism via .mli
      files. Each of these visibility levels corresponds to a directory in a
      package's build directory. *)
  type t =
    | Private
    | Private_c
    | Public
    | Public_for_lsp
end

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

module Generated_file : sig
  module Compiled : sig
    type t

    val equal : t -> t -> bool
    val path : t -> Basename.t
    val visibility : t -> Visibility.t
    val lib_cmx : t
    val lib_cmi : t
    val exe_cmx : t

    (** Rename the file, preserving its extension. *)
    val rename : t -> name_without_extension:string -> Visibility.t -> t
  end

  module Linked_library : sig
    type t =
      | Cmxa
      | Cma
      | A

    val path : t -> Basename.t
  end

  module Linked_executable : sig
    type t =
      | Native of Basename.t
      | Bytecode of Basename.t

    val path : t -> Basename.t
  end

  type t =
    | Generated_ocaml_source of Basename.t
    | Compiled of Compiled.t
    | Linked_library of Linked_library.t
    | Linked_executable of Linked_executable.t

  val to_dyn : t -> Dyn.t
  val equal : t -> t -> bool

  module Set : Set.S with type elt = t
  module Map : Map.S with type key = t

  val path : t -> Basename.t
  val lib_cmx : t
  val lib_cmi : t
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

module File_type : sig
  type ml
  type mli
  type cmx
  type cmo
  type cmi
  type cmt
  type cmti
  type o
  type exe_native
  type exe_bytecode
  type a
  type cmxa
  type cma
  type c
end

open File_type

module File : sig
  module Ocaml_source_or_interface : sig
    (** ['a] is either [ml] or [mli] *)
    type 'a t

    val path : _ t -> Absolute_path.non_root_t

    val of_path_by_extension
      :  Absolute_path.non_root_t
      -> ([ `Ml of ml t | `Mli of mli t ], [ `Unknown_extension of string ]) result
  end

  module C_source : sig
    type t

    val of_path : Absolute_path.non_root_t -> t
    val path : t -> Absolute_path.non_root_t
  end

  module Generated_ocaml_source : sig
    type t

    val of_basename : Basename.t -> t
    val basename : t -> Basename.t
    val generated_file : t -> Generated_file.t
  end

  module Compiled : sig
    type 'a t

    val equal : 'a t -> 'a t -> bool
    val path : _ t -> Basename.t
    val cmx_private : Basename.t -> cmx t
    val cmi_private : Basename.t -> cmi t
    val o_private : Basename.t -> o t
    val o_private_c : Basename.t -> o t

    (** The .cmx compiled file associated with the given .cmi interface file *)
    val cmx_of_cmi : cmi t -> cmx t

    val ml_of_cmi : cmi t -> ml t

    val of_path_by_extension_private
      :  Basename.t
      -> ( [ `Cmx of cmx t | `Cmi of cmi t | `O of o t ]
           , [ `Unknown_extension of string ] )
           result

    val generated_file : _ t -> Generated_file.t
    val generated_file_compiled : _ t -> Generated_file.Compiled.t
    val lib_cmx : cmx t
    val lib_cmi : cmi t
    val exe_cmx : cmx t
    val rename : 'a t -> name_without_extension:string -> Visibility.t -> 'a t

    (** The .o file with the same name as a .cmx file (besides its extension)
        with the same visibility. *)
    val o_of_cmx : cmx t -> o t

    val visibility : _ t -> Visibility.t
  end

  module Linked : sig
    type 'a t

    val to_dyn : _ t -> Dyn.t
    val lib_cmxa : cmxa t
    val lib_cma : cma t
    val lib_a : a t
    val exe_native : Basename.t -> exe_native t
    val exe_bytecode : Basename.t -> exe_bytecode t
    val generated_file : _ t -> Generated_file.t
    val path : _ t -> Basename.t
  end
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
