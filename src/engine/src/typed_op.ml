open! Alice_stdlib
open Alice_hierarchy
open Alice_error

module Visibility = struct
  type t =
    | Private
    | Private_c
    | Public
    | Public_for_lsp

  let to_dyn = function
    | Private -> Dyn.variant "Private" []
    | Private_c -> Dyn.variant "Private_c" []
    | Public -> Dyn.variant "Public" []
    | Public_for_lsp -> Dyn.variant "Public_for_lsp" []
  ;;

  let equal a b =
    match a, b with
    | Private, Private -> true
    | Private, _ -> false
    | Private_c, Private_c -> true
    | Private_c, _ -> false
    | Public, Public -> true
    | Public, _ -> false
    | Public_for_lsp, Public_for_lsp -> true
    | Public_for_lsp, _ -> false
  ;;

  let compare a b =
    match a, b with
    | Private, Private -> 0
    | Private, _ -> -1
    | _, Private -> 1
    | Private_c, Private_c -> 0
    | Private_c, _ -> -1
    | _, Private_c -> 1
    | Public, Public -> 0
    | Public, _ -> -1
    | _, Public -> 1
    | Public_for_lsp, Public_for_lsp -> 0
  ;;
end

let lib_base = Basename.remove_extension Alice_package.Package.lib_root_ml
let exe_base = Basename.remove_extension Alice_package.Package.exe_root_ml
let lib_cmx = Basename.add_extension lib_base ~ext:".cmx"
let lib_cmi = Basename.add_extension lib_base ~ext:".cmi"
let exe_cmx = Basename.add_extension exe_base ~ext:".cmx"

module Generated_file = struct
  module Compiled = struct
    type t =
      { path : Basename.t
      ; visibility : Visibility.t
      }

    let to_dyn { path; visibility } =
      Dyn.record
        [ "path", Basename.to_dyn path; "visibility", Visibility.to_dyn visibility ]
    ;;

    let equal t { path; visibility } =
      Basename.equal t.path path && Visibility.equal t.visibility visibility
    ;;

    let compare t { path; visibility } =
      let open Compare in
      let= () = Basename.compare t.path path in
      let= () = Visibility.compare t.visibility visibility in
      0
    ;;

    let path { path; _ } = path
    let visibility { visibility; _ } = visibility
    let lib_cmx = { path = lib_cmx; visibility = Private }
    let lib_cmi = { path = lib_cmi; visibility = Private }

    let rename t ~name_without_extension visibility =
      let ext = Basename.extension t.path in
      let path =
        Basename.of_filename name_without_extension |> Basename.add_extension ~ext
      in
      { path; visibility }
    ;;

    let cmt_for_lsp package_name =
      { path =
          Basename.of_filename (Alice_package.Package_name.to_string package_name)
          |> Basename.add_extension ~ext:".cmt"
      ; visibility = Public_for_lsp
      }
    ;;
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
      match a, b with
      | Cmxa, Cmxa -> 0
      | Cmxa, _ -> -1
      | _, Cmxa -> 1
      | A, A -> 0
    ;;

    let path = function
      | Cmxa -> Basename.of_filename "lib.cmxa"
      | A -> Basename.of_filename "lib.a"
    ;;
  end

  module T = struct
    type t =
      | Generated_ocaml_source of Basename.t
      | Compiled of Compiled.t
      | Linked_library of Linked_library.t
      | Linked_executable of Basename.t

    let to_dyn = function
      | Generated_ocaml_source path ->
        Dyn.variant "Generated_ocaml_source" [ Basename.to_dyn path ]
      | Compiled compiled -> Dyn.variant "Compiled" [ Compiled.to_dyn compiled ]
      | Linked_library linked_library ->
        Dyn.variant "Linked_library" [ Linked_library.to_dyn linked_library ]
      | Linked_executable path -> Dyn.variant "Linked_executable" [ Basename.to_dyn path ]
    ;;

    let equal a b =
      match a, b with
      | Generated_ocaml_source a, Generated_ocaml_source b -> Basename.equal a b
      | Generated_ocaml_source _, _ -> false
      | Compiled a, Compiled b -> Compiled.equal a b
      | Compiled _, _ -> false
      | Linked_library a, Linked_library b -> Linked_library.equal a b
      | Linked_library _, _ -> false
      | Linked_executable a, Linked_executable b -> Basename.equal a b
      | Linked_executable _, _ -> false
    ;;

    let compare a b =
      match a, b with
      | Generated_ocaml_source a, Generated_ocaml_source b -> Basename.compare a b
      | Generated_ocaml_source _, _ -> -1
      | _, Generated_ocaml_source _ -> 1
      | Compiled a, Compiled b -> Compiled.compare a b
      | Compiled _, _ -> -1
      | _, Compiled _ -> 1
      | Linked_library a, Linked_library b -> Linked_library.compare a b
      | Linked_library _, _ -> -1
      | _, Linked_library _ -> 1
      | Linked_executable a, Linked_executable b -> Basename.compare a b
    ;;

    let lib_cmx = Compiled Compiled.lib_cmx
    let lib_cmi = Compiled Compiled.lib_cmi
  end

  include T
  module Map = Map.Make (T)
  module Set = Set.Make (T)

  let path = function
    | Generated_ocaml_source path -> path
    | Compiled compiled -> Compiled.path compiled
    | Linked_library linked_library -> Linked_library.path linked_library
    | Linked_executable path -> path
  ;;

  let cmt_for_lsp package_name = Compiled (Compiled.cmt_for_lsp package_name)
end

module File_type = struct
  type ml = Ml [@@warning "-37"]
  type mli = Mli [@@warning "-37"]
  type cmx = Cmx [@@warning "-37"]
  type cmi = Cmi [@@warning "-37"]
  type cmt = Cmt [@@warning "-37"]
  type cmti = Cmti [@@warning "-37"]
  type o = O [@@warning "-37"]
  type exe = Exe [@@warning "-37"]
  type a = A [@@warning "-37"]
  type cmxa = Cmxa [@@warning "-37"]
  type c = Cmxa [@@warning "-37"]

  type _ t =
    | Ml : ml t
    | Mli : mli t
    | Cmx : cmx t
    | Cmi : cmi t
    | Cmt : cmt t
    | Cmti : cmti t
    | O : o t

  let to_dyn : type a. a t -> Dyn.t =
    fun t ->
    let tag =
      match t with
      | Ml -> "Ml"
      | Mli -> "Mli"
      | Cmx -> "Cmx"
      | Cmi -> "Cmi"
      | Cmt -> "Cmt"
      | Cmti -> "Cmti"
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
    | Cmt, Cmt -> true
    | Cmti, Cmti -> true
    | O, O -> true
  ;;

  let compare : type a. a t -> a t -> int =
    fun a b ->
    match a, b with
    | Ml, Ml -> 0
    | Mli, Mli -> 0
    | Cmx, Cmx -> 0
    | Cmi, Cmi -> 0
    | Cmt, Cmt -> 0
    | Cmti, Cmti -> 0
    | O, O -> 0
  ;;
end

open File_type

module File = struct
  module Ocaml_source_or_interface = struct
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

    let compare t { path; type_ } =
      let open Compare in
      let= () = Absolute_path.compare t.path path in
      File_type.compare t.type_ type_
    ;;
  end

  module C_source = struct
    type t = Absolute_path.non_root_t

    let to_dyn = Absolute_path.to_dyn
    let equal = Absolute_path.equal
    let compare = Absolute_path.compare

    let of_path t =
      if Absolute_path.has_extension t ~ext:".c"
      then t
      else
        panic
          [ Pp.textf
              "Expected c source file to have extension \".c\" but got %S."
              (Absolute_path.to_filename t)
          ]
    ;;

    let path t = t
  end

  module Generated_ocaml_source = struct
    type t = Basename.t

    let to_dyn = Basename.to_dyn
    let equal = Basename.equal
    let compare = Basename.compare

    let of_basename t =
      if Basename.has_extension t ~ext:".ml"
      then t
      else
        panic
          [ Pp.textf
              "Expected generated OCaml source file to have extension \".ml\" but got %S."
              (Basename.to_filename t)
          ]
    ;;

    let basename t = t
    let generated_file t = Generated_file.Generated_ocaml_source t
  end

  module Compiled = struct
    type 'type_ t =
      { path : Basename.t
      ; type_ : 'type_ File_type.t
      ; visibility : Visibility.t
      }

    let to_dyn { path; type_; visibility } =
      Dyn.record
        [ "path", Basename.to_dyn path
        ; "type_", File_type.to_dyn type_
        ; "visibility", Visibility.to_dyn visibility
        ]
    ;;

    let equal t { path; type_; visibility } =
      Basename.equal t.path path
      && File_type.equal t.type_ type_
      && Visibility.equal t.visibility visibility
    ;;

    let compare t { path; type_; visibility } =
      let open Compare in
      let= () = Basename.compare t.path path in
      let= () = File_type.compare t.type_ type_ in
      Visibility.compare t.visibility visibility
    ;;

    let of_path_checked path type_ ext ~visibility =
      if Basename.has_extension path ~ext
      then { path; type_; visibility }
      else
        panic
          [ Pp.textf "Path %S does not have extension %S." (Basename.to_filename path) ext
          ]
    ;;

    let cmx_private path = of_path_checked path Cmx ".cmx" ~visibility:Private
    let cmx_public path = of_path_checked path Cmx ".cmx" ~visibility:Public
    let cmi_private path = of_path_checked path Cmi ".cmi" ~visibility:Private
    let cmi_public path = of_path_checked path Cmi ".cmi" ~visibility:Public
    let o_private path = of_path_checked path O ".o" ~visibility:Private
    let o_private_c path = of_path_checked path O ".o" ~visibility:Private_c

    let cmt_public_for_lsp path =
      of_path_checked path Cmt ".cmt" ~visibility:Public_for_lsp
    ;;

    let cmti_public_for_lsp path =
      of_path_checked path Cmti ".cmti" ~visibility:Public_for_lsp
    ;;

    let cmi_public_for_lsp path =
      of_path_checked path Cmi ".cmi" ~visibility:Public_for_lsp
    ;;

    let of_path_by_extension_private path =
      match Basename.extension path with
      | ".cmx" -> Ok (`Cmx (cmx_private path))
      | ".cmi" -> Ok (`Cmi (cmi_private path))
      | ".o" -> Ok (`O (o_private path))
      | unknown -> Error (`Unknown_extension unknown)
    ;;

    let path { path; _ } = path

    let generated_file_compiled { path; visibility; _ } =
      { Generated_file.Compiled.path; visibility }
    ;;

    let generated_file t = Generated_file.Compiled (generated_file_compiled t)
    let lib_cmx = cmx_private lib_cmx
    let lib_cmi = cmi_private lib_cmi
    let exe_cmx = cmx_private exe_cmx
    let visibility { visibility; _ } = visibility

    let rename t ~name_without_extension visibility =
      let ext = Basename.extension t.path in
      let path =
        Basename.of_filename name_without_extension |> Basename.add_extension ~ext
      in
      { path; type_ = t.type_; visibility }
    ;;

    let o_of_cmx ({ path; type_ = _; visibility } : cmx t) =
      { path = Basename.replace_extension path ~ext:".o"; type_ = O; visibility }
    ;;

    let cmt_of_cmx ({ path; type_ = _; visibility } : cmx t) =
      { path = Basename.replace_extension path ~ext:".cmt"; type_ = Cmt; visibility }
    ;;

    let cmti_of_cmi ({ path; type_ = _; visibility } : cmi t) =
      { path = Basename.replace_extension path ~ext:".cmti"; type_ = Cmti; visibility }
    ;;
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
      | Lib_a, Lib_a -> true
      | Exe a, Exe b -> Basename.equal a b
    ;;

    let compare : type a. a t -> a t -> int =
      fun a b ->
      match a, b with
      | Lib_cmxa, Lib_cmxa -> 0
      | Lib_a, Lib_a -> 0
      | Exe a, Exe b -> Basename.compare a b
    ;;

    let generated_file : type a. a t -> Generated_file.t = function
      | Lib_cmxa -> Generated_file.Linked_library Cmxa
      | Lib_a -> Generated_file.Linked_library A
      | Exe name -> Generated_file.Linked_executable name
    ;;

    let path t = generated_file t |> Generated_file.path
  end
end

module Pack = struct
  open Alice_package

  type t = Package_name.t

  let equal = Package_name.equal
  let compare = Package_name.compare
  let to_dyn = Package_name.to_dyn
  let of_package_name t = t
  let package_name t = t
  let module_name t = Module_name.internal_modules t

  let cmx_file t =
    let basename =
      Module_name.basename_without_extension (module_name t)
      |> Basename.add_extension ~ext:".cmx"
    in
    File.Compiled.cmx_public basename
  ;;
end

module Compile_ocaml_source = struct
  type t =
    { source_input : ml File.Ocaml_source_or_interface.t
    ; compiled_inputs : Generated_file.Compiled.t list
    ; cmx_output : cmx File.Compiled.t
    ; interface_output_if_no_matching_mli_is_present : cmi File.Compiled.t option
    ; stop_after_typing : bool
    }

  let equal
        t
        { source_input
        ; compiled_inputs
        ; cmx_output
        ; interface_output_if_no_matching_mli_is_present
        ; stop_after_typing
        }
    =
    File.Ocaml_source_or_interface.equal t.source_input source_input
    && List.equal t.compiled_inputs compiled_inputs ~eq:Generated_file.Compiled.equal
    && File.Compiled.equal t.cmx_output cmx_output
    && Option.equal
         ~eq:File.Compiled.equal
         t.interface_output_if_no_matching_mli_is_present
         interface_output_if_no_matching_mli_is_present
    && Bool.equal t.stop_after_typing stop_after_typing
  ;;

  let compare
        t
        { source_input
        ; compiled_inputs
        ; cmx_output
        ; interface_output_if_no_matching_mli_is_present
        ; stop_after_typing
        }
    =
    let open Compare in
    let= () = File.Ocaml_source_or_interface.compare t.source_input source_input in
    let= () =
      List.compare ~cmp:Generated_file.Compiled.compare t.compiled_inputs compiled_inputs
    in
    let= () = File.Compiled.compare t.cmx_output cmx_output in
    let= () =
      Option.compare
        ~cmp:File.Compiled.compare
        t.interface_output_if_no_matching_mli_is_present
        interface_output_if_no_matching_mli_is_present
    in
    Bool.compare t.stop_after_typing stop_after_typing
  ;;

  let to_dyn
        { source_input
        ; compiled_inputs
        ; cmx_output
        ; interface_output_if_no_matching_mli_is_present
        ; stop_after_typing
        }
    =
    Dyn.record
      [ "source_input", File.Ocaml_source_or_interface.to_dyn source_input
      ; "compiled_inputs", Dyn.list Generated_file.Compiled.to_dyn compiled_inputs
      ; "cmx_output", File.Compiled.to_dyn cmx_output
      ; ( "interface_output_if_no_matching_mli_is_present"
        , Dyn.option File.Compiled.to_dyn interface_output_if_no_matching_mli_is_present )
      ; "stop_after_typing", Dyn.bool stop_after_typing
      ]
  ;;
end

module Compile_ocaml_interface = struct
  type t =
    { interface_input : mli File.Ocaml_source_or_interface.t
    ; compiled_inputs : Generated_file.Compiled.t list
    ; cmi_output : cmi File.Compiled.t
    ; stop_after_typing : bool
    }

  let equal t { interface_input; compiled_inputs; cmi_output; stop_after_typing } =
    File.Ocaml_source_or_interface.equal t.interface_input interface_input
    && List.equal t.compiled_inputs compiled_inputs ~eq:Generated_file.Compiled.equal
    && File.Compiled.equal t.cmi_output cmi_output
    && Bool.equal t.stop_after_typing stop_after_typing
  ;;

  let compare t { interface_input; compiled_inputs; cmi_output; stop_after_typing } =
    let open Compare in
    let= () = File.Ocaml_source_or_interface.compare t.interface_input interface_input in
    let= () =
      List.compare ~cmp:Generated_file.Compiled.compare t.compiled_inputs compiled_inputs
    in
    let= () = File.Compiled.compare t.cmi_output cmi_output in
    Bool.compare t.stop_after_typing stop_after_typing
  ;;

  let to_dyn { interface_input; compiled_inputs; cmi_output; stop_after_typing } =
    Dyn.record
      [ "interface_input", File.Ocaml_source_or_interface.to_dyn interface_input
      ; "compiled_inputs", Dyn.list Generated_file.Compiled.to_dyn compiled_inputs
      ; "cmi_output", File.Compiled.to_dyn cmi_output
      ; "stop_after_typing", Dyn.bool stop_after_typing
      ]
  ;;
end

module Compile_c_source = struct
  type t =
    { source_input : File.C_source.t
    ; object_output : o File.Compiled.t
    }

  let equal t { source_input; object_output } =
    File.C_source.equal t.source_input source_input
    && File.Compiled.equal t.object_output object_output
  ;;

  let compare t { source_input; object_output } =
    let open Compare in
    let= () = File.C_source.compare t.source_input source_input in
    File.Compiled.compare t.object_output object_output
  ;;

  let to_dyn { source_input; object_output } =
    Dyn.record
      [ "source_input", File.C_source.to_dyn source_input
      ; "object_output", File.Compiled.to_dyn object_output
      ]
  ;;
end

module Pack_library = struct
  type t =
    { cmx_inputs : cmx File.Compiled.t list
    ; pack : Pack.t
    }

  let equal t { cmx_inputs; pack } =
    List.equal ~eq:File.Compiled.equal t.cmx_inputs cmx_inputs && Pack.equal t.pack pack
  ;;

  let compare t { cmx_inputs; pack } =
    let open Compare in
    let= () = List.compare ~cmp:File.Compiled.compare t.cmx_inputs cmx_inputs in
    Pack.compare t.pack pack
  ;;

  let to_dyn { cmx_inputs; pack } =
    Dyn.record
      [ "cmx_inputs", Dyn.list File.Compiled.to_dyn cmx_inputs; "pack", Pack.to_dyn pack ]
  ;;
end

module Generate_public_interface_to_open = struct
  type t = { ml_output : File.Generated_ocaml_source.t }

  let equal t { ml_output } = File.Generated_ocaml_source.equal t.ml_output ml_output
  let compare t { ml_output } = File.Generated_ocaml_source.compare t.ml_output ml_output

  let to_dyn { ml_output } =
    Dyn.record [ "ml_output", File.Generated_ocaml_source.to_dyn ml_output ]
  ;;
end

module Compile_public_interface_to_open = struct
  type t =
    { generated_source_input : File.Generated_ocaml_source.t
    ; internal_modules_pack : Pack.t
    ; cmx_output : cmx File.Compiled.t
    ; cmi_output : cmi File.Compiled.t
    }

  let create
        ~(generated_source_input : File.Generated_ocaml_source.t)
        ~internal_modules_pack
    =
    let open File.Compiled in
    let basename = generated_source_input in
    { generated_source_input
    ; internal_modules_pack
    ; cmx_output = Basename.replace_extension basename ~ext:".cmx" |> cmx_public
    ; cmi_output = Basename.replace_extension basename ~ext:".cmi" |> cmi_public
    }
  ;;

  let equal t { generated_source_input; internal_modules_pack; cmx_output; cmi_output } =
    File.Generated_ocaml_source.equal t.generated_source_input generated_source_input
    && Pack.equal t.internal_modules_pack internal_modules_pack
    && File.Compiled.equal t.cmx_output cmx_output
    && File.Compiled.equal t.cmi_output cmi_output
  ;;

  let compare t { generated_source_input; internal_modules_pack; cmx_output; cmi_output } =
    let open Compare in
    let= () =
      File.Generated_ocaml_source.compare t.generated_source_input generated_source_input
    in
    let= () = Pack.compare t.internal_modules_pack internal_modules_pack in
    let= () = File.Compiled.compare t.cmx_output cmx_output in
    File.Compiled.compare t.cmi_output cmi_output
  ;;

  let to_dyn { generated_source_input; internal_modules_pack; cmx_output; cmi_output } =
    Dyn.record
      [ ( "generated_source_input"
        , File.Generated_ocaml_source.to_dyn generated_source_input )
      ; "internal_modules_pack", Pack.to_dyn internal_modules_pack
      ; "cmx_output", File.Compiled.to_dyn cmx_output
      ; "cmi_output", File.Compiled.to_dyn cmi_output
      ]
  ;;
end

module Link_library = struct
  type t =
    { cmx_inputs : cmx File.Compiled.t list
    ; compiled_c_inputs : o File.Compiled.t list
    ; cmxa_output : cmxa File.Linked.t
    ; a_output : a File.Linked.t
    }

  let equal t { cmx_inputs; compiled_c_inputs; cmxa_output; a_output } =
    List.equal t.cmx_inputs cmx_inputs ~eq:File.Compiled.equal
    && List.equal t.compiled_c_inputs compiled_c_inputs ~eq:File.Compiled.equal
    && File.Linked.equal t.cmxa_output cmxa_output
    && File.Linked.equal t.a_output a_output
  ;;

  let compare t { cmx_inputs; compiled_c_inputs; cmxa_output; a_output } =
    let open Compare in
    let= () = List.compare ~cmp:File.Compiled.compare t.cmx_inputs cmx_inputs in
    let= () =
      List.compare ~cmp:File.Compiled.compare t.compiled_c_inputs compiled_c_inputs
    in
    let= () = File.Linked.compare t.cmxa_output cmxa_output in
    File.Linked.compare t.a_output a_output
  ;;

  let to_dyn { cmx_inputs; compiled_c_inputs; cmxa_output; a_output } =
    Dyn.record
      [ "cmx_inputs", Dyn.list File.Compiled.to_dyn cmx_inputs
      ; "compiled_c_inputs", Dyn.list File.Compiled.to_dyn compiled_c_inputs
      ; "cmxa_output", File.Linked.to_dyn cmxa_output
      ; "a_output", File.Linked.to_dyn a_output
      ]
  ;;

  let of_inputs ~cmx_inputs ~compiled_c_inputs =
    { cmx_inputs; compiled_c_inputs; cmxa_output = Lib_cmxa; a_output = Lib_a }
  ;;
end

module Link_executable = struct
  type t =
    { cmx_inputs : cmx File.Compiled.t list
    ; compiled_c_inputs : o File.Compiled.t list
    ; exe_output : exe File.Linked.t
    }

  let equal t { cmx_inputs; compiled_c_inputs; exe_output } =
    List.equal t.cmx_inputs cmx_inputs ~eq:File.Compiled.equal
    && List.equal t.compiled_c_inputs compiled_c_inputs ~eq:File.Compiled.equal
    && File.Linked.equal t.exe_output exe_output
  ;;

  let compare t { cmx_inputs; compiled_c_inputs; exe_output } =
    let open Compare in
    let= () = List.compare ~cmp:File.Compiled.compare t.cmx_inputs cmx_inputs in
    let= () =
      List.compare ~cmp:File.Compiled.compare t.compiled_c_inputs compiled_c_inputs
    in
    File.Linked.compare t.exe_output exe_output
  ;;

  let to_dyn { cmx_inputs; compiled_c_inputs; exe_output } =
    Dyn.record
      [ "cmx_inputs", Dyn.list File.Compiled.to_dyn cmx_inputs
      ; "compiled_c_inputs", Dyn.list File.Compiled.to_dyn compiled_c_inputs
      ; "exe_output", File.Linked.to_dyn exe_output
      ]
  ;;
end

module T = struct
  type t =
    | Compile_ocaml_source of Compile_ocaml_source.t
    | Compile_ocaml_interface of Compile_ocaml_interface.t
    | Compile_c_source of Compile_c_source.t
    | Pack_library of Pack_library.t
    | Generate_public_interface_to_open of Generate_public_interface_to_open.t
    | Compile_public_interface_to_open of Compile_public_interface_to_open.t
    | Link_library of Link_library.t
    | Link_executable of Link_executable.t

  let equal a b =
    match a, b with
    | Compile_ocaml_source a, Compile_ocaml_source b -> Compile_ocaml_source.equal a b
    | Compile_ocaml_source _, _ -> false
    | Compile_ocaml_interface a, Compile_ocaml_interface b ->
      Compile_ocaml_interface.equal a b
    | Compile_ocaml_interface _, _ -> false
    | Compile_c_source a, Compile_c_source b -> Compile_c_source.equal a b
    | Compile_c_source _, _ -> false
    | Pack_library a, Pack_library b -> Pack_library.equal a b
    | Pack_library _, _ -> false
    | Generate_public_interface_to_open a, Generate_public_interface_to_open b ->
      Generate_public_interface_to_open.equal a b
    | Generate_public_interface_to_open _, _ -> false
    | Compile_public_interface_to_open a, Compile_public_interface_to_open b ->
      Compile_public_interface_to_open.equal a b
    | Compile_public_interface_to_open _, _ -> false
    | Link_library a, Link_library b -> Link_library.equal a b
    | Link_library _, _ -> false
    | Link_executable a, Link_executable b -> Link_executable.equal a b
    | Link_executable _, _ -> false
  ;;

  let compare a b =
    match a, b with
    | Compile_ocaml_source a, Compile_ocaml_source b -> Compile_ocaml_source.compare a b
    | Compile_ocaml_source _, _ -> -1
    | _, Compile_ocaml_source _ -> 1
    | Compile_ocaml_interface a, Compile_ocaml_interface b ->
      Compile_ocaml_interface.compare a b
    | Compile_ocaml_interface _, _ -> -1
    | _, Compile_ocaml_interface _ -> 1
    | Compile_c_source a, Compile_c_source b -> Compile_c_source.compare a b
    | Compile_c_source _, _ -> -1
    | _, Compile_c_source _ -> 1
    | Pack_library a, Pack_library b -> Pack_library.compare a b
    | Pack_library _, _ -> -1
    | _, Pack_library _ -> 1
    | Generate_public_interface_to_open a, Generate_public_interface_to_open b ->
      Generate_public_interface_to_open.compare a b
    | Generate_public_interface_to_open _, _ -> -1
    | _, Generate_public_interface_to_open _ -> 1
    | Compile_public_interface_to_open a, Compile_public_interface_to_open b ->
      Compile_public_interface_to_open.compare a b
    | Compile_public_interface_to_open _, _ -> -1
    | _, Compile_public_interface_to_open _ -> 1
    | Link_library a, Link_library b -> Link_library.compare a b
    | Link_library _, _ -> -1
    | _, Link_library _ -> 1
    | Link_executable a, Link_executable b -> Link_executable.compare a b
  ;;

  let to_dyn = function
    | Compile_ocaml_source compile_source ->
      Dyn.variant "Compile_ocaml_source" [ Compile_ocaml_source.to_dyn compile_source ]
    | Compile_ocaml_interface compile_interface ->
      Dyn.variant
        "Compile_ocaml_interface"
        [ Compile_ocaml_interface.to_dyn compile_interface ]
    | Compile_c_source compile_source ->
      Dyn.variant "Compile_c_source" [ Compile_c_source.to_dyn compile_source ]
    | Pack_library pack_library ->
      Dyn.variant "Pack_library" [ Pack_library.to_dyn pack_library ]
    | Generate_public_interface_to_open generate_public_interface_to_open ->
      Dyn.variant
        "Generate_public_interface_to_open"
        [ Generate_public_interface_to_open.to_dyn generate_public_interface_to_open ]
    | Compile_public_interface_to_open compile_generated_source ->
      Dyn.variant
        "Compile_public_interface_to_open"
        [ Compile_public_interface_to_open.to_dyn compile_generated_source ]
    | Link_library link_library ->
      Dyn.variant "Link_library" [ Link_library.to_dyn link_library ]
    | Link_executable link_executable ->
      Dyn.variant "Link_executable" [ Link_executable.to_dyn link_executable ]
  ;;
end

include T
module Map = Map.Make (T)
module Set = Set.Make (T)

let source_input = function
  | Compile_ocaml_source { source_input; _ } ->
    Some (File.Ocaml_source_or_interface.path source_input)
  | Compile_ocaml_interface { interface_input; _ } ->
    Some (File.Ocaml_source_or_interface.path interface_input)
  | Compile_c_source { source_input; _ } -> Some (File.C_source.path source_input)
  | Pack_library _
  | Generate_public_interface_to_open _
  | Compile_public_interface_to_open _
  | Link_library _
  | Link_executable _ -> None
;;

let generated_inputs t =
  let compiled_generated = File.Compiled.generated_file in
  match t with
  | Compile_ocaml_source { compiled_inputs; _ }
  | Compile_ocaml_interface { compiled_inputs; _ } ->
    List.map compiled_inputs ~f:(fun compiled -> Generated_file.Compiled compiled)
  | Compile_c_source _ -> []
  | Pack_library { cmx_inputs; _ } -> List.map cmx_inputs ~f:compiled_generated
  | Generate_public_interface_to_open _ -> []
  | Compile_public_interface_to_open { generated_source_input; internal_modules_pack; _ }
    ->
    [ File.Generated_ocaml_source.generated_file generated_source_input
    ; Pack.cmx_file internal_modules_pack |> File.Compiled.generated_file
    ]
  | Link_library { cmx_inputs; compiled_c_inputs; _ } ->
    List.map compiled_c_inputs ~f:compiled_generated
    @ List.map cmx_inputs ~f:compiled_generated
  | Link_executable { cmx_inputs; compiled_c_inputs; _ } ->
    List.map compiled_c_inputs ~f:compiled_generated
    @ List.map cmx_inputs ~f:compiled_generated
;;

let outputs = function
  | Compile_ocaml_source
      { cmx_output; interface_output_if_no_matching_mli_is_present; stop_after_typing; _ }
    ->
    (if stop_after_typing then [] else [ File.Compiled.generated_file cmx_output ])
    @ [ File.Compiled.cmt_of_cmx cmx_output |> File.Compiled.generated_file ]
    @ (Option.map
         interface_output_if_no_matching_mli_is_present
         ~f:File.Compiled.generated_file
       |> Option.to_list)
  | Compile_ocaml_interface { cmi_output; _ } ->
    [ File.Compiled.generated_file cmi_output
    ; File.Compiled.cmti_of_cmi cmi_output |> File.Compiled.generated_file
    ]
  | Compile_c_source { object_output; _ } ->
    [ File.Compiled.generated_file object_output ]
  | Pack_library { pack; _ } -> [ File.Compiled.generated_file (Pack.cmx_file pack) ]
  | Generate_public_interface_to_open { ml_output } ->
    [ File.Generated_ocaml_source.generated_file ml_output ]
  | Compile_public_interface_to_open { cmx_output; _ } ->
    [ File.Compiled.generated_file cmx_output ]
  | Link_library { cmxa_output; a_output; _ } ->
    [ File.Linked.generated_file cmxa_output; File.Linked.generated_file a_output ]
  | Link_executable { exe_output; _ } -> [ File.Linked.generated_file exe_output ]
;;
