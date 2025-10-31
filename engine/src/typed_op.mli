open! Alice_stdlib
open Alice_hierarchy

module File_type : sig
  type ml
  type mli
  type cmx
  type cmi
  type o
  type exe
  type a
  type cmxa
end

open File_type

module File : sig
  module Source : sig
    type 'a t

    val of_path_by_extension
      :  Path.Absolute.t
      -> ([ `Ml of ml t | `Mli of mli t ], [ `Unknown_extension of string ]) result
  end

  module Compiled : sig
    type 'a t

    val cmx_infer_role_from_name : Path.Relative.t -> cmx t
    val cmi_infer_role_from_name : Path.Relative.t -> cmi t
    val o_infer_role_from_name : Path.Relative.t -> o t

    val of_path_by_extension_infer_role_from_name
      :  Path.Relative.t
      -> ( [ `Cmx of cmx t | `Cmi of cmi t | `O of o t ]
           , [ `Unknown_extension of string ] )
           result
  end

  module Linked : sig
    type 'a t

    val lib_cmxa : cmxa t
    val lib_a : a t
    val exe : Path.Relative.t -> exe t
    val path : _ t -> Path.Relative.t
  end
end

module Compile_source : sig
  type t =
    { direct_input : ml File.Source.t
    ; indirect_inputs : [ `Cmx of cmx File.Compiled.t | `Cmi of cmi File.Compiled.t ] list
    ; direct_output : cmx File.Compiled.t
    ; indirect_output : o File.Compiled.t
    ; interface_output_if_no_matching_mli_is_present : cmi File.Compiled.t option
    }
end

module Compile_interface : sig
  type t =
    { direct_input : mli File.Source.t
    ; indirect_inputs : cmi File.Compiled.t list
    ; direct_output : cmi File.Compiled.t
    }
end

module Link_library : sig
  type t =
    { direct_inputs : cmx File.Compiled.t list
    ; direct_output : cmxa File.Linked.t
    ; indirect_output : a File.Linked.t
    }

  val of_inputs : cmx File.Compiled.t list -> t
end

module Link_executable : sig
  type t =
    { direct_inputs : cmx File.Compiled.t list
    ; direct_output : exe File.Linked.t
    }
end

type t =
  | Compile_source of Compile_source.t
  | Compile_interface of Compile_interface.t
  | Link_library of Link_library.t
  | Link_executable of Link_executable.t

val equal : t -> t -> bool
val to_dyn : t -> Dyn.t
val generated_inputs : t -> Path.Relative.t list
val outputs : t -> Path.Relative.t list
