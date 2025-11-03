open! Alice_stdlib
open Alice_hierarchy
open Alice_error

module Role = struct
  type t =
    | Internal
    | Lib
    | Exe

  let to_dyn t =
    let tag =
      match t with
      | Internal -> "Internal"
      | Lib -> "Lib"
      | Exe -> "Exe"
    in
    Dyn.variant tag []
  ;;

  let equal a b =
    match a, b with
    | Internal, Internal -> true
    | Internal, _ -> false
    | Lib, Lib -> true
    | Lib, _ -> false
    | Exe, Exe -> true
    | Exe, _ -> false
  ;;

  let compare a b =
    let to_int = function
      | Internal -> 0
      | Lib -> 1
      | Exe -> 2
    in
    Int.compare (to_int a) (to_int b)
  ;;
end

module Generated_file = struct
  module Compiled = struct
    type t =
      { path : Basename.t
      ; role : Role.t
      }

    let to_dyn { path; role } =
      Dyn.record [ "path", Basename.to_dyn path; "role", Role.to_dyn role ]
    ;;

    let equal t { path; role } = Basename.equal t.path path && Role.equal t.role role

    let compare t { path; role } =
      match Basename.compare t.path path with
      | 0 -> Role.compare t.role role
      | other -> other
    ;;

    let path { path; _ } = path
  end

  module Linked_library = struct
    type t =
      | Cmxa
      | A

    let to_dyn = function
      | Cmxa -> Dyn.variant "Cmxa" []
      | A -> Dyn.variant "A" []
    ;;

    let equal a b =
      match a, b with
      | Cmxa, Cmxa -> true
      | Cmxa, _ -> false
      | A, A -> true
      | A, _ -> false
    ;;

    let compare a b =
      let to_int = function
        | Cmxa -> 0
        | A -> 1
      in
      Int.compare (to_int a) (to_int b)
    ;;

    let path = function
      | Cmxa -> Basename.of_filename "lib.cmxa"
      | A -> Basename.of_filename "lib.a"
    ;;
  end

  module T = struct
    type t =
      | Compiled of Compiled.t
      | Linked_library of Linked_library.t
      | Linked_executable of Basename.t

    let to_dyn = function
      | Compiled compiled -> Dyn.variant "Compiled" [ Compiled.to_dyn compiled ]
      | Linked_library linked_library ->
        Dyn.variant "Linked_library" [ Linked_library.to_dyn linked_library ]
      | Linked_executable path -> Dyn.variant "Linked_executable" [ Basename.to_dyn path ]
    ;;

    let equal a b =
      match a, b with
      | Compiled a, Compiled b -> Compiled.equal a b
      | Compiled _, _ -> false
      | Linked_library a, Linked_library b -> Linked_library.equal a b
      | Linked_library _, _ -> false
      | Linked_executable a, Linked_executable b -> Basename.equal a b
      | Linked_executable _, _ -> false
    ;;

    let compare a b =
      match a, b with
      | Compiled a, Compiled b -> Compiled.compare a b
      | Compiled _, (Linked_library _ | Linked_executable _) -> -1
      | Linked_library a, Linked_library b -> Linked_library.compare a b
      | Linked_library _, Compiled _ -> 1
      | Linked_library _, Linked_executable _ -> -1
      | Linked_executable a, Linked_executable b -> Basename.compare a b
      | Linked_executable _, (Compiled _ | Linked_library _) -> 1
    ;;
  end

  include T
  module Map = Map.Make (T)
  module Set = Set.Make (T)

  let path = function
    | Compiled compiled -> Compiled.path compiled
    | Linked_library linked_library -> Linked_library.path linked_library
    | Linked_executable path -> path
  ;;
end

module File_type = struct
  type ml = |
  type mli = |
  type cmx = |
  type cmi = |
  type o = |
  type exe = |
  type a = |
  type cmxa = |

  type _ t =
    | Ml : ml t
    | Mli : mli t
    | Cmx : cmx t
    | Cmi : cmi t
    | O : o t

  let to_dyn : type a. a t -> Dyn.t =
    fun t ->
    let tag =
      match t with
      | Ml -> "Ml"
      | Mli -> "Mli"
      | Cmx -> "Cmx"
      | Cmi -> "Cmi"
      | O -> "O"
    in
    Dyn.variant tag []
  ;;

  let equal : type a. a t -> a t -> bool =
    fun a b ->
    match a, b with
    | Ml, Ml -> true
    | Mli, Mli -> true
    | Cmx, Cmx -> true
    | Cmi, Cmi -> true
    | O, O -> true
  ;;
end

open File_type

module File = struct
  module Source = struct
    type 'type_ t =
      { path : Absolute_path.non_root_t
      ; type_ : 'type_ File_type.t
      }

    let to_dyn { path; type_ } =
      Dyn.record [ "path", Absolute_path.to_dyn path; "type_", File_type.to_dyn type_ ]
    ;;

    let equal t { path; type_ } =
      Absolute_path.equal t.path path && File_type.equal t.type_ type_
    ;;

    let path { path; _ } = path
    let ml path = { path; type_ = Ml }
    let mli path = { path; type_ = Mli }

    let of_path_by_extension path =
      match Absolute_path.extension path with
      | ".ml" -> Ok (`Ml (ml path))
      | ".mli" -> Ok (`Mli (mli path))
      | unknown -> Error (`Unknown_extension unknown)
    ;;
  end

  module Compiled = struct
    type 'type_ t =
      { path : Basename.t
      ; type_ : 'type_ File_type.t
      ; role : Role.t
      }

    let to_dyn { path; type_; role } =
      Dyn.record
        [ "path", Basename.to_dyn path
        ; "type_", File_type.to_dyn type_
        ; "role", Role.to_dyn role
        ]
    ;;

    let equal t { path; type_; role } =
      Basename.equal t.path path
      && File_type.equal t.type_ type_
      && Role.equal t.role role
    ;;

    let lib_base = Basename.remove_extension Alice_package.Package.lib_root_ml
    let exe_base = Basename.remove_extension Alice_package.Package.exe_root_ml

    let of_path_checked_infer_role_from_name path type_ ext =
      if Basename.has_extension path ~ext
      then (
        let base = Basename.remove_extension path in
        let role =
          if Basename.equal base lib_base
          then Role.Lib
          else if Basename.equal base exe_base
          then Exe
          else Internal
        in
        { path; type_; role })
      else
        panic
          [ Pp.textf "Path %S does not have extension %S." (Basename.to_filename path) ext
          ]
    ;;

    let cmx_infer_role_from_name path =
      of_path_checked_infer_role_from_name path Cmx ".cmx"
    ;;

    let cmi_infer_role_from_name path =
      of_path_checked_infer_role_from_name path Cmi ".cmi"
    ;;

    let o_infer_role_from_name path = of_path_checked_infer_role_from_name path O ".o"

    let of_path_by_extension_infer_role_from_name path =
      match Basename.extension path with
      | ".cmx" -> Ok (`Cmx (cmx_infer_role_from_name path))
      | ".cmi" -> Ok (`Cmi (cmi_infer_role_from_name path))
      | ".o" -> Ok (`O (o_infer_role_from_name path))
      | unknown -> Error (`Unknown_extension unknown)
    ;;

    let path { path; _ } = path
    let role { role; _ } = role
    let generated_file_compiled { path; role; _ } = { Generated_file.Compiled.path; role }
    let generated_file t = Generated_file.Compiled (generated_file_compiled t)
  end

  module Linked = struct
    type _ t =
      | Lib_cmxa : cmxa t
      | Lib_a : a t
      | Exe : Basename.t -> exe t

    let lib_cmxa = Lib_cmxa
    let lib_a = Lib_a
    let exe name = Exe name

    let to_dyn : type a. a t -> Dyn.t = function
      | Lib_cmxa -> Dyn.variant "Lib_cmxa" []
      | Lib_a -> Dyn.variant "Lib_a" []
      | Exe path -> Dyn.variant "Exe" [ Basename.to_dyn path ]
    ;;

    let equal : type a. a t -> a t -> bool =
      fun a b ->
      match a, b with
      | Lib_cmxa, Lib_cmxa -> true
      | Lib_cmxa, _ -> false
      | Lib_a, Lib_a -> true
      | Lib_a, _ -> false
      | Exe a, Exe b -> Basename.equal a b
      | Exe _, _ -> false
    ;;

    let generated_file : type a. a t -> Generated_file.t = function
      | Lib_cmxa -> Generated_file.Linked_library Cmxa
      | Lib_a -> Generated_file.Linked_library A
      | Exe name -> Generated_file.Linked_executable name
    ;;

    let path t = generated_file t |> Generated_file.path
  end
end

module Compile_source = struct
  type t =
    { source_input : ml File.Source.t
    ; compiled_inputs : [ `Cmx of cmx File.Compiled.t | `Cmi of cmi File.Compiled.t ] list
    ; cmx_output : cmx File.Compiled.t
    ; o_output : o File.Compiled.t
    ; interface_output_if_no_matching_mli_is_present : cmi File.Compiled.t option
    }

  let equal
        t
        { source_input
        ; compiled_inputs
        ; cmx_output
        ; o_output
        ; interface_output_if_no_matching_mli_is_present
        }
    =
    File.Source.equal t.source_input source_input
    && List.equal t.compiled_inputs compiled_inputs ~eq:(fun a b ->
      match a, b with
      | `Cmx a, `Cmx b -> File.Compiled.equal a b
      | `Cmx _, _ -> false
      | `Cmi a, `Cmi b -> File.Compiled.equal a b
      | `Cmi _, _ -> false)
    && File.Compiled.equal t.cmx_output cmx_output
    && File.Compiled.equal t.o_output o_output
    && Option.equal
         ~eq:File.Compiled.equal
         t.interface_output_if_no_matching_mli_is_present
         interface_output_if_no_matching_mli_is_present
  ;;

  let to_dyn
        { source_input
        ; compiled_inputs
        ; cmx_output
        ; o_output
        ; interface_output_if_no_matching_mli_is_present
        }
    =
    Dyn.record
      [ "source_input", File.Source.to_dyn source_input
      ; ( "compiled_inputs"
        , Dyn.list
            (function
              | `Cmx file -> Dyn.variant "Cmx" [ File.Compiled.to_dyn file ]
              | `Cmi file -> Dyn.variant "Cmi" [ File.Compiled.to_dyn file ])
            compiled_inputs )
      ; "cmx_output", File.Compiled.to_dyn cmx_output
      ; "o_output", File.Compiled.to_dyn o_output
      ; ( "interface_output_if_no_matching_mli_is_present"
        , Dyn.option File.Compiled.to_dyn interface_output_if_no_matching_mli_is_present )
      ]
  ;;
end

module Compile_interface = struct
  type t =
    { interface_input : mli File.Source.t
    ; cmi_inputs : cmi File.Compiled.t list
    ; cmi_output : cmi File.Compiled.t
    }

  let equal t { interface_input; cmi_inputs; cmi_output } =
    File.Source.equal t.interface_input interface_input
    && List.equal t.cmi_inputs cmi_inputs ~eq:File.Compiled.equal
    && File.Compiled.equal t.cmi_output cmi_output
  ;;

  let to_dyn { interface_input; cmi_inputs; cmi_output } =
    Dyn.record
      [ "interface_input", File.Source.to_dyn interface_input
      ; "cmi_inputs", Dyn.list File.Compiled.to_dyn cmi_inputs
      ; "cmi_output", File.Compiled.to_dyn cmi_output
      ]
  ;;
end

module Link_library = struct
  type t =
    { cmx_inputs : cmx File.Compiled.t list
    ; cmxa_output : cmxa File.Linked.t
    ; a_output : a File.Linked.t
    }

  let equal t { cmx_inputs; cmxa_output; a_output } =
    List.equal t.cmx_inputs cmx_inputs ~eq:File.Compiled.equal
    && File.Linked.equal t.cmxa_output cmxa_output
    && File.Linked.equal t.a_output a_output
  ;;

  let to_dyn { cmx_inputs; cmxa_output; a_output } =
    Dyn.record
      [ "cmx_inputs", Dyn.list File.Compiled.to_dyn cmx_inputs
      ; "cmxa_output", File.Linked.to_dyn cmxa_output
      ; "a_output", File.Linked.to_dyn a_output
      ]
  ;;

  let of_inputs cmx_inputs = { cmx_inputs; cmxa_output = Lib_cmxa; a_output = Lib_a }
end

module Link_executable = struct
  type t =
    { cmx_inputs : cmx File.Compiled.t list
    ; exe_output : exe File.Linked.t
    }

  let equal t { cmx_inputs; exe_output } =
    List.equal t.cmx_inputs cmx_inputs ~eq:File.Compiled.equal
    && File.Linked.equal t.exe_output exe_output
  ;;

  let to_dyn { cmx_inputs; exe_output } =
    Dyn.record
      [ "cmx_inputs", Dyn.list File.Compiled.to_dyn cmx_inputs
      ; "exe_output", File.Linked.to_dyn exe_output
      ]
  ;;
end

type t =
  | Compile_source of Compile_source.t
  | Compile_interface of Compile_interface.t
  | Link_library of Link_library.t
  | Link_executable of Link_executable.t

let equal a b =
  match a, b with
  | Compile_source a, Compile_source b -> Compile_source.equal a b
  | Compile_source _, _ -> false
  | Compile_interface a, Compile_interface b -> Compile_interface.equal a b
  | Compile_interface _, _ -> false
  | Link_library a, Link_library b -> Link_library.equal a b
  | Link_library _, _ -> false
  | Link_executable a, Link_executable b -> Link_executable.equal a b
  | Link_executable _, _ -> false
;;

let to_dyn = function
  | Compile_source compile_source ->
    Dyn.variant "Compile_source" [ Compile_source.to_dyn compile_source ]
  | Compile_interface compile_interface ->
    Dyn.variant "Compile_interface" [ Compile_interface.to_dyn compile_interface ]
  | Link_library link_library ->
    Dyn.variant "Link_library" [ Link_library.to_dyn link_library ]
  | Link_executable link_executable ->
    Dyn.variant "Link_executable" [ Link_executable.to_dyn link_executable ]
;;

let source_input = function
  | Compile_source { source_input; _ } -> Some (File.Source.path source_input)
  | Compile_interface { interface_input; _ } -> Some (File.Source.path interface_input)
  | Link_library _ -> None
  | Link_executable _ -> None
;;

let compiled_inputs = function
  | Compile_source { compiled_inputs; _ } ->
    List.map compiled_inputs ~f:(function
      | `Cmx file -> File.Compiled.generated_file_compiled file
      | `Cmi file -> File.Compiled.generated_file_compiled file)
  | Compile_interface { cmi_inputs; _ } ->
    List.map cmi_inputs ~f:File.Compiled.generated_file_compiled
  | Link_library { cmx_inputs; _ } ->
    List.map cmx_inputs ~f:File.Compiled.generated_file_compiled
  | Link_executable { cmx_inputs; _ } ->
    List.map cmx_inputs ~f:File.Compiled.generated_file_compiled
;;

let outputs = function
  | Compile_source
      { cmx_output; o_output; interface_output_if_no_matching_mli_is_present; _ } ->
    [ File.Compiled.generated_file cmx_output; File.Compiled.generated_file o_output ]
    @ (Option.map
         interface_output_if_no_matching_mli_is_present
         ~f:File.Compiled.generated_file
       |> Option.to_list)
  | Compile_interface { cmi_output; _ } -> [ File.Compiled.generated_file cmi_output ]
  | Link_library { cmxa_output; a_output; _ } ->
    [ File.Linked.generated_file cmxa_output; File.Linked.generated_file a_output ]
  | Link_executable { exe_output; _ } -> [ File.Linked.generated_file exe_output ]
;;
