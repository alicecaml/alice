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
  type 'a source
  type 'a generated

  val compiled_cmx : Path.Relative.t -> cmx generated
  val compiled_cmi : Path.Relative.t -> cmi generated
  val compiled_o : Path.Relative.t -> o generated

  val source_by_extension
    :  Path.Absolute.t
    -> ( [ `Ml of ml source | `Mli of mli source ]
         , [ `Unknown_extension of string ] )
         result

  val compiled_by_extension
    :  Path.Relative.t
    -> ( [ `Cmx of cmx generated | `Cmi of cmi generated | `O of o generated ]
         , [ `Unknown_extension of string ] )
         result
end

module Compile_source : sig
  type t =
    { direct_input : ml File.source
    ; indirect_inputs : [ `Cmx of cmx File.generated | `Cmi of cmi File.generated ] list
    ; direct_output : cmx File.generated
    ; indirect_output : o File.generated
    }
end

module Compile_interface : sig
  type t =
    { direct_input : mli File.source
    ; indirect_inputs : cmi File.generated list
    ; direct_output : cmi File.generated
    }
end

module Link_library : sig
  type t =
    { direct_inputs : cmx File.generated list
    ; direct_output : cmxa File.generated
    ; indirect_output : a File.generated
    }
end

module Link_executable : sig
  type t =
    { direct_inputs : cmx File.generated list
    ; direct_output : exe File.generated
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
