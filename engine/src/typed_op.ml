open! Alice_stdlib
open Alice_hierarchy
open Alice_error

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
    | Exe : exe t
    | A : a t
    | Cmxa : cmxa t

  let to_dyn : type a. a t -> Dyn.t =
    fun t ->
    let tag =
      match t with
      | Ml -> "Ml"
      | Mli -> "Mli"
      | Cmx -> "Cmx"
      | Cmi -> "Cmi"
      | O -> "O"
      | Exe -> "Exe"
      | A -> "A"
      | Cmxa -> "Cmxa"
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
    | Exe, Exe -> true
    | A, A -> true
    | Cmxa, Cmxa -> true
  ;;
end

open File_type

module File = struct
  module Source = struct
    type 'type_ t =
      { path : Path.Absolute.t
      ; type_ : 'type_ File_type.t
      }

    let to_dyn { path; type_ } =
      Dyn.record [ "path", Path.Absolute.to_dyn path; "type_", File_type.to_dyn type_ ]
    ;;

    let equal t { path; type_ } =
      Path.Absolute.equal t.path path && File_type.equal t.type_ type_
    ;;

    let ml path = { path; type_ = Ml }
    let mli path = { path; type_ = Mli }

    let of_path_by_extension path =
      match Path.Absolute.extension path with
      | ".ml" -> Ok (`Ml (ml path))
      | ".mli" -> Ok (`Mli (mli path))
      | unknown -> Error (`Unknown_extension unknown)
    ;;
  end

  module Compiled = struct
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
    end

    type 'type_ t =
      { path : Path.Relative.t
      ; type_ : 'type_ File_type.t
      ; role : Role.t
      }

    let to_dyn { path; type_; role } =
      Dyn.record
        [ "path", Path.Relative.to_dyn path
        ; "type_", File_type.to_dyn type_
        ; "role", Role.to_dyn role
        ]
    ;;

    let equal t { path; type_; role } =
      Path.Relative.equal t.path path
      && File_type.equal t.type_ type_
      && Role.equal t.role role
    ;;

    let lib_base = Path.remove_extension Alice_package.Package.lib_root_ml
    let exe_base = Path.remove_extension Alice_package.Package.exe_root_ml

    let of_path_checked_infer_role_from_name path type_ ext =
      if Path.has_extension path ~ext
      then (
        let base = Path.remove_extension path in
        let role =
          if Path.equal base lib_base
          then Role.Lib
          else if Path.equal base exe_base
          then Exe
          else Internal
        in
        { path; type_; role })
      else
        panic
          [ Pp.textf
              "Path %S does not have extension %S."
              (Alice_ui.path_to_string path)
              ext
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
      match Path.Relative.extension path with
      | ".cmx" -> Ok (`Cmx (cmx_infer_role_from_name path))
      | ".cmi" -> Ok (`Cmi (cmi_infer_role_from_name path))
      | ".o" -> Ok (`O (o_infer_role_from_name path))
      | unknown -> Error (`Unknown_extension unknown)
    ;;

    let path { path; _ } = path
  end

  module Linked = struct
    type _ t =
      | Lib_cmxa : cmxa t
      | Lib_a : a t
      | Exe : Path.Relative.t -> exe t

    let lib_cmxa = Lib_cmxa
    let lib_a = Lib_a
    let exe name = Exe name

    let to_dyn : type a. a t -> Dyn.t = function
      | Lib_cmxa -> Dyn.variant "Lib_cmxa" []
      | Lib_a -> Dyn.variant "Lib_a" []
      | Exe path -> Dyn.variant "Exe" [ Path.Relative.to_dyn path ]
    ;;

    let equal : type a. a t -> a t -> bool =
      fun a b ->
      match a, b with
      | Lib_cmxa, Lib_cmxa -> true
      | Lib_cmxa, _ -> false
      | Lib_a, Lib_a -> true
      | Lib_a, _ -> false
      | Exe a, Exe b -> Path.Relative.equal a b
      | Exe _, _ -> false
    ;;

    let path : type a. a t -> Path.Relative.t = function
      | Lib_cmxa -> Path.relative "lib.cmxa"
      | Lib_a -> Path.relative "lib.a"
      | Exe name -> name
    ;;
  end
end

module Compile_source = struct
  type t =
    { direct_input : ml File.Source.t
    ; indirect_inputs : [ `Cmx of cmx File.Compiled.t | `Cmi of cmi File.Compiled.t ] list
    ; direct_output : cmx File.Compiled.t
    ; indirect_output : o File.Compiled.t
    ; interface_output_if_no_matching_mli_is_present : cmi File.Compiled.t option
    }

  let equal
        t
        { direct_input
        ; indirect_inputs
        ; direct_output
        ; indirect_output
        ; interface_output_if_no_matching_mli_is_present
        }
    =
    File.Source.equal t.direct_input direct_input
    && List.equal t.indirect_inputs indirect_inputs ~eq:(fun a b ->
      match a, b with
      | `Cmx a, `Cmx b -> File.Compiled.equal a b
      | `Cmx _, _ -> false
      | `Cmi a, `Cmi b -> File.Compiled.equal a b
      | `Cmi _, _ -> false)
    && File.Compiled.equal t.direct_output direct_output
    && File.Compiled.equal t.indirect_output indirect_output
    && Option.equal
         ~eq:File.Compiled.equal
         t.interface_output_if_no_matching_mli_is_present
         interface_output_if_no_matching_mli_is_present
  ;;

  let to_dyn
        { direct_input
        ; indirect_inputs
        ; direct_output
        ; indirect_output
        ; interface_output_if_no_matching_mli_is_present
        }
    =
    Dyn.record
      [ "direct_input", File.Source.to_dyn direct_input
      ; ( "indirect_inputs"
        , Dyn.list
            (function
              | `Cmx file -> Dyn.variant "Cmx" [ File.Compiled.to_dyn file ]
              | `Cmi file -> Dyn.variant "Cmi" [ File.Compiled.to_dyn file ])
            indirect_inputs )
      ; "direct_output", File.Compiled.to_dyn direct_output
      ; "indirect_output", File.Compiled.to_dyn indirect_output
      ; ( "interface_output_if_no_matching_mli_is_present"
        , Dyn.option File.Compiled.to_dyn interface_output_if_no_matching_mli_is_present )
      ]
  ;;
end

module Compile_interface = struct
  type t =
    { direct_input : mli File.Source.t
    ; indirect_inputs : cmi File.Compiled.t list
    ; direct_output : cmi File.Compiled.t
    }

  let equal t { direct_input; indirect_inputs; direct_output } =
    File.Source.equal t.direct_input direct_input
    && List.equal t.indirect_inputs indirect_inputs ~eq:File.Compiled.equal
    && File.Compiled.equal t.direct_output direct_output
  ;;

  let to_dyn { direct_input; indirect_inputs; direct_output } =
    Dyn.record
      [ "direct_input", File.Source.to_dyn direct_input
      ; "indirect_inputs", Dyn.list File.Compiled.to_dyn indirect_inputs
      ; "direct_output", File.Compiled.to_dyn direct_output
      ]
  ;;
end

module Link_library = struct
  type t =
    { direct_inputs : cmx File.Compiled.t list
    ; direct_output : cmxa File.Linked.t
    ; indirect_output : a File.Linked.t
    }

  let equal t { direct_inputs; direct_output; indirect_output } =
    List.equal t.direct_inputs direct_inputs ~eq:File.Compiled.equal
    && File.Linked.equal t.direct_output direct_output
    && File.Linked.equal t.indirect_output indirect_output
  ;;

  let to_dyn { direct_inputs; direct_output; indirect_output } =
    Dyn.record
      [ "direct_inputs", Dyn.list File.Compiled.to_dyn direct_inputs
      ; "direct_output", File.Linked.to_dyn direct_output
      ; "indirect_output", File.Linked.to_dyn indirect_output
      ]
  ;;

  let of_inputs direct_inputs =
    { direct_inputs; direct_output = Lib_cmxa; indirect_output = Lib_a }
  ;;
end

module Link_executable = struct
  type t =
    { direct_inputs : cmx File.Compiled.t list
    ; direct_output : exe File.Linked.t
    }

  let equal t { direct_inputs; direct_output } =
    List.equal t.direct_inputs direct_inputs ~eq:File.Compiled.equal
    && File.Linked.equal t.direct_output direct_output
  ;;

  let to_dyn { direct_inputs; direct_output } =
    Dyn.record
      [ "direct_inputs", Dyn.list File.Compiled.to_dyn direct_inputs
      ; "direct_output", File.Linked.to_dyn direct_output
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

let generated_inputs = function
  | Compile_source { indirect_inputs; _ } ->
    List.map indirect_inputs ~f:(function
      | `Cmx file -> File.Compiled.path file
      | `Cmi file -> File.Compiled.path file)
  | Compile_interface { indirect_inputs; _ } ->
    List.map indirect_inputs ~f:File.Compiled.path
  | Link_library { direct_inputs; _ } -> List.map direct_inputs ~f:File.Compiled.path
  | Link_executable { direct_inputs; _ } -> List.map direct_inputs ~f:File.Compiled.path
;;

let outputs = function
  | Compile_source
      { direct_output
      ; indirect_output
      ; interface_output_if_no_matching_mli_is_present
      ; _
      } ->
    [ File.Compiled.path direct_output; File.Compiled.path indirect_output ]
    @ (Option.map interface_output_if_no_matching_mli_is_present ~f:File.Compiled.path
       |> Option.to_list)
  | Compile_interface { direct_output; _ } -> [ File.Compiled.path direct_output ]
  | Link_library { direct_output; indirect_output; _ } ->
    [ File.Linked.path direct_output; File.Linked.path indirect_output ]
  | Link_executable { direct_output; _ } -> [ File.Linked.path direct_output ]
;;
