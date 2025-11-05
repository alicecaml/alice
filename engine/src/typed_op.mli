open! Alice_stdlib
open Alice_hierarchy

module Visibility : sig
  type t =
    | Public
    | Private
end

module Generated_file : sig
  module Compiled : sig
    type t

    val path : t -> Basename.t
    val visibility : t -> Visibility.t
  end

  module Linked_library : sig
    type t =
      | Cmxa
      | A

    val path : t -> Basename.t
  end

  type t =
    | Compiled of Compiled.t
    | Linked_library of Linked_library.t
    | Linked_executable of Basename.t

  val to_dyn : t -> Dyn.t
  val equal : t -> t -> bool

  module Set : Set.S with type elt = t
  module Map : Map.S with type key = t

  val path : t -> Basename.t
end

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

    val path : _ t -> Absolute_path.non_root_t

    val of_path_by_extension
      :  Absolute_path.non_root_t
      -> ([ `Ml of ml t | `Mli of mli t ], [ `Unknown_extension of string ]) result
  end

  module Compiled : sig
    type 'a t

    val path : _ t -> Basename.t
    val cmx_private : Basename.t -> cmx t
    val cmi_private : Basename.t -> cmi t
    val o_private : Basename.t -> o t

    val of_path_by_extension_private
      :  Basename.t
      -> ( [ `Cmx of cmx t | `Cmi of cmi t | `O of o t ]
           , [ `Unknown_extension of string ] )
           result

    val generated_file : _ t -> Generated_file.t
    val lib_cmx : cmx t
    val exe_cmx : cmx t
  end

  module Linked : sig
    type 'a t

    val to_dyn : _ t -> Dyn.t
    val lib_cmxa : cmxa t
    val lib_a : a t
    val exe : Basename.t -> exe t
    val generated_file : _ t -> Generated_file.t
    val path : _ t -> Basename.t
  end
end

module Compile_source : sig
  type t =
    { source_input : ml File.Source.t
    ; compiled_inputs : [ `Cmx of cmx File.Compiled.t | `Cmi of cmi File.Compiled.t ] list
    ; cmx_output : cmx File.Compiled.t
    ; o_output : o File.Compiled.t
    ; interface_output_if_no_matching_mli_is_present : cmi File.Compiled.t option
    }
end

module Compile_interface : sig
  type t =
    { interface_input : mli File.Source.t
    ; cmi_inputs : cmi File.Compiled.t list
    ; cmi_output : cmi File.Compiled.t
    }
end

module Link_library : sig
  type t =
    { cmx_inputs : cmx File.Compiled.t list
    ; cmxa_output : cmxa File.Linked.t
    ; a_output : a File.Linked.t
    }

  val of_inputs : cmx File.Compiled.t list -> t
end

module Link_executable : sig
  type t =
    { cmx_inputs : cmx File.Compiled.t list
    ; exe_output : exe File.Linked.t
    }
end

type t =
  | Compile_source of Compile_source.t
  | Compile_interface of Compile_interface.t
  | Link_library of Link_library.t
  | Link_executable of Link_executable.t

val equal : t -> t -> bool
val to_dyn : t -> Dyn.t
val source_input : t -> Absolute_path.non_root_t option
val compiled_inputs : t -> Generated_file.Compiled.t list
val outputs : t -> Generated_file.t list
