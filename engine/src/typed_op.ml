open! Alice_stdlib
open Alice_hierarchy
open Alice_error

module File_type = struct
  type ml = Ml
  type mli = Mli
  type cmx = Cmx
  type cmi = Cmi
  type o = O
  type exe = Exe
  type a = A
  type cmxa = Cmxa
end

open File_type

module File = struct
  type 'type_ source =
    { path : Path.Absolute.t
    ; type_ : 'type_
    }

  let source_equal (t : _ source) { path; type_ = _ } = Path.Absolute.equal t.path path
  let source_ml path = { path; type_ = Ml }
  let source_mli path = { path; type_ = Mli }

  type 'type_ generated =
    { path : Path.Relative.t
    ; type_ : 'type_
    }

  let generated_equal (t : _ generated) { path; type_ = _ } =
    Path.Relative.equal t.path path
  ;;

  let compiled_path_checked path type_ ext =
    if Path.has_extension path ~ext
    then { path; type_ }
    else
      panic
        [ Pp.textf
            "Path %S does not have extension %S."
            (Alice_ui.path_to_string path)
            ext
        ]
  ;;

  let compiled_cmx path = compiled_path_checked path Cmx ".cmx"
  let compiled_cmi path = compiled_path_checked path Cmi ".cmi"
  let compiled_o path = compiled_path_checked path O ".o"
  let linked_exe path = { path; type_ = Exe }
  let linked_a path = { path; type_ = A }
  let linked_cmxa path = { path; type_ = Cmxa }

  let source_by_extension path =
    match Path.Absolute.extension path with
    | ".ml" -> Ok (`Ml (source_ml path))
    | ".mli" -> Ok (`Mli (source_mli path))
    | unknown -> Error (`Unknown_extension unknown)
  ;;

  let compiled_by_extension path =
    match Path.Relative.extension path with
    | ".cmx" -> Ok (`Cmx (compiled_cmx path))
    | ".cmi" -> Ok (`Cmi (compiled_cmi path))
    | ".o" -> Ok (`O (compiled_o path))
    | unknown -> Error (`Unknown_extension unknown)
  ;;

  let generated_path ({ path; _ } : _ generated) = path
end

module Compile_source = struct
  type t =
    { direct_input : ml File.source
    ; indirect_inputs : [ `Cmx of cmx File.generated | `Cmi of cmi File.generated ] list
    ; direct_output : cmx File.generated
    ; indirect_output : o File.generated
    }

  let equal t { direct_input; indirect_inputs; direct_output; indirect_output } =
    File.source_equal t.direct_input direct_input
    && List.equal t.indirect_inputs indirect_inputs ~eq:(fun a b ->
      match a, b with
      | `Cmx a, `Cmx b -> File.generated_equal a b
      | `Cmx _, _ -> false
      | `Cmi a, `Cmi b -> File.generated_equal a b
      | `Cmi _, _ -> false)
    && File.generated_equal t.direct_output direct_output
    && File.generated_equal t.indirect_output indirect_output
  ;;

  let to_dyn { direct_input; indirect_inputs; direct_output; indirect_output } =
    Dyn.record
      [ "direct_input", Path.Absolute.to_dyn direct_input.path
      ; ( "indirect_inputs"
        , Dyn.list
            (function
              | `Cmx file ->
                Dyn.variant "Cmx" [ Path.Relative.to_dyn (File.generated_path file) ]
              | `Cmi file ->
                Dyn.variant "Cmi" [ Path.Relative.to_dyn (File.generated_path file) ])
            indirect_inputs )
      ; "direct_output", Path.Relative.to_dyn direct_output.path
      ; "indirect_output", Path.Relative.to_dyn indirect_output.path
      ]
  ;;
end

module Compile_interface = struct
  type t =
    { direct_input : mli File.source
    ; indirect_inputs : cmi File.generated list
    ; direct_output : cmi File.generated
    }

  let equal t { direct_input; indirect_inputs; direct_output } =
    File.source_equal t.direct_input direct_input
    && List.equal t.indirect_inputs indirect_inputs ~eq:File.generated_equal
    && File.generated_equal t.direct_output direct_output
  ;;

  let to_dyn { direct_input; indirect_inputs; direct_output } =
    Dyn.record
      [ "direct_input", Path.Absolute.to_dyn direct_input.path
      ; ( "indirect_inputs"
        , Dyn.list Path.Relative.to_dyn (List.map indirect_inputs ~f:File.generated_path)
        )
      ; "direct_output", Path.Relative.to_dyn direct_output.path
      ]
  ;;
end

module Link_library = struct
  type t =
    { direct_inputs : cmx File.generated list
    ; direct_output : cmxa File.generated
    ; indirect_output : a File.generated
    }

  let equal t { direct_inputs; direct_output; indirect_output } =
    List.equal t.direct_inputs direct_inputs ~eq:File.generated_equal
    && File.generated_equal t.direct_output direct_output
    && File.generated_equal t.indirect_output indirect_output
  ;;

  let to_dyn { direct_inputs; direct_output; indirect_output } =
    Dyn.record
      [ ( "direct_inputs"
        , Dyn.list Path.Relative.to_dyn (List.map direct_inputs ~f:File.generated_path) )
      ; "direct_output", Path.Relative.to_dyn direct_output.path
      ; "indirect_output", Path.Relative.to_dyn indirect_output.path
      ]
  ;;
end

module Link_executable = struct
  type t =
    { direct_inputs : cmx File.generated list
    ; direct_output : exe File.generated
    }

  let equal t { direct_inputs; direct_output } =
    List.equal t.direct_inputs direct_inputs ~eq:File.generated_equal
    && File.generated_equal t.direct_output direct_output
  ;;

  let to_dyn { direct_inputs; direct_output } =
    Dyn.record
      [ ( "direct_inputs"
        , Dyn.list Path.Relative.to_dyn (List.map direct_inputs ~f:File.generated_path) )
      ; "direct_output", Path.Relative.to_dyn direct_output.path
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
      | `Cmx file -> File.generated_path file
      | `Cmi file -> File.generated_path file)
  | Compile_interface { indirect_inputs; _ } ->
    List.map indirect_inputs ~f:File.generated_path
  | Link_library { direct_inputs; _ } -> List.map direct_inputs ~f:File.generated_path
  | Link_executable { direct_inputs; _ } -> List.map direct_inputs ~f:File.generated_path
;;

let outputs = function
  | Compile_source { direct_output; indirect_output; _ } ->
    [ File.generated_path direct_output; File.generated_path indirect_output ]
  | Compile_interface { direct_output; _ } -> [ File.generated_path direct_output ]
  | Link_library { direct_output; indirect_output; _ } ->
    [ File.generated_path direct_output; File.generated_path indirect_output ]
  | Link_executable { direct_output; _ } -> [ File.generated_path direct_output ]
;;
