open! Alice_stdlib
open Alice_hierarchy
open Alice_error
open Alice_ocaml_toolchain
open Alice_package

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

module Out_dir = struct
  type t =
    | Private
    | Private_c
    | Public
    | Public_for_lsp
    | Generated_src
    | Executable

  let to_dyn = function
    | Private -> Dyn.variant "Private" []
    | Private_c -> Dyn.variant "Private_c" []
    | Public -> Dyn.variant "Public" []
    | Public_for_lsp -> Dyn.variant "Public_for_lsp" []
    | Generated_src -> Dyn.variant "Generated_src" []
    | Executable -> Dyn.variant "Executable" []
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
    | Generated_src, Generated_src -> true
    | Generated_src, _ -> false
    | Executable, Executable -> true
    | Executable, _ -> false
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
    | Public_for_lsp, _ -> -1
    | _, Public_for_lsp -> 1
    | Generated_src, Generated_src -> 0
    | Generated_src, _ -> -1
    | _, Generated_src -> 1
    | Executable, Executable -> 0
  ;;
end

let lib_base = Basename.remove_extension Package.lib_root_ml
let exe_base = Basename.remove_extension Package.exe_root_ml
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
    let exe_cmx = { path = exe_cmx; visibility = Private }

    let rename t ~name_without_extension visibility =
      let ext = Basename.extension t.path in
      let path =
        Basename.of_filename name_without_extension |> Basename.add_extension ~ext
      in
      { path; visibility }
    ;;

    let replace_extension_with_cmt t =
      { path = Basename.replace_extension t.path ~ext:".cmt"; visibility = t.visibility }
    ;;

    let replace_extension_with_cmti t =
      { path = Basename.replace_extension t.path ~ext:".cmti"; visibility = t.visibility }
    ;;
  end

  module Linked_library = struct
    type t =
      | Cmxa
      | Cma
      | A

    let to_dyn = function
      | Cmxa -> Dyn.variant "Cmxa" []
      | Cma -> Dyn.variant "Cma" []
      | A -> Dyn.variant "A" []
    ;;

    let equal a b =
      match a, b with
      | Cmxa, Cmxa -> true
      | Cmxa, _ -> false
      | Cma, Cma -> true
      | Cma, _ -> false
      | A, A -> true
      | A, _ -> false
    ;;

    let compare a b =
      match a, b with
      | Cmxa, Cmxa -> 0
      | Cmxa, _ -> -1
      | _, Cmxa -> 1
      | Cma, Cma -> 0
      | Cma, _ -> -1
      | _, Cma -> 1
      | A, A -> 0
    ;;

    let path = function
      | Cmxa -> Basename.of_filename "lib.cmxa"
      | Cma -> Basename.of_filename "lib.cma"
      | A -> Basename.of_filename "lib.a"
    ;;
  end

  module Linked_executable = struct
    type t =
      | Native of Basename.t
      | Bytecode of Basename.t

    let to_dyn = function
      | Native name | Bytecode name -> Dyn.variant "Bytecode" [ Basename.to_dyn name ]
    ;;

    let equal a b =
      match a, b with
      | Native a, Native b | Bytecode a, Bytecode b -> Basename.equal a b
      | _, _ -> false
    ;;

    let compare a b =
      match a, b with
      | Native a, Native b -> Basename.compare a b
      | Native _, _ -> -1
      | _, Native _ -> 1
      | Bytecode a, Bytecode b -> Basename.compare a b
    ;;

    let path = function
      | Native path | Bytecode path -> path
    ;;
  end

  module T = struct
    type t =
      | Generated_ocaml_source of Basename.t
      | Compiled of Compiled.t
      | Linked_library of Linked_library.t
      | Linked_executable of Linked_executable.t

    let to_dyn = function
      | Generated_ocaml_source path ->
        Dyn.variant "Generated_ocaml_source" [ Basename.to_dyn path ]
      | Compiled compiled -> Dyn.variant "Compiled" [ Compiled.to_dyn compiled ]
      | Linked_library linked_library ->
        Dyn.variant "Linked_library" [ Linked_library.to_dyn linked_library ]
      | Linked_executable linked_executable ->
        Dyn.variant "Linked_executable" [ Linked_executable.to_dyn linked_executable ]
    ;;

    let equal a b =
      match a, b with
      | Generated_ocaml_source a, Generated_ocaml_source b -> Basename.equal a b
      | Generated_ocaml_source _, _ -> false
      | Compiled a, Compiled b -> Compiled.equal a b
      | Compiled _, _ -> false
      | Linked_library a, Linked_library b -> Linked_library.equal a b
      | Linked_library _, _ -> false
      | Linked_executable a, Linked_executable b -> Linked_executable.equal a b
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
      | Linked_executable a, Linked_executable b -> Linked_executable.compare a b
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
    | Linked_executable linked_executable -> Linked_executable.path linked_executable
  ;;
end

module File_type = struct
  type ml = Ml [@@warning "-37"]
  type mli = Mli [@@warning "-37"]
  type cmx = Cmx [@@warning "-37"]
  type cmo = Cmx [@@warning "-37"]
  type cmi = Cmi [@@warning "-37"]
  type cmt = Cmt [@@warning "-37"]
  type cmti = Cmti [@@warning "-37"]
  type o = O [@@warning "-37"]
  type exe_native = Exe_native [@@warning "-37"]
  type exe_bytecode = Exe_bytecode [@@warning "-37"]
  type a = A [@@warning "-37"]
  type cmxa = Cmxa [@@warning "-37"]
  type cma = Cma [@@warning "-37"]
  type c = Cmxa [@@warning "-37"]

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

  let compare : type a. a t -> a t -> int =
    fun a b ->
    match a, b with
    | Ml, Ml -> 0
    | Mli, Mli -> 0
    | Cmx, Cmx -> 0
    | Cmi, Cmi -> 0
    | O, O -> 0
  ;;
end

module Src_file = struct
  include Absolute_path

  type t = non_root_t

  let make path ~ext =
    assert_extension path ~ext;
    path
  ;;

  let of_path path =
    match extension path with
    | ".ml" -> Ok (`Ml path)
    | ".mli" -> Ok (`Mli path)
    | ".c" -> Ok (`C path)
    | other -> Error (`Unknown_extension other)
  ;;

  let of_path_ml path = make path ~ext:".ml"
  let of_path_mli path = make path ~ext:".mli"
  let of_path_c path = make path ~ext:".c"
  let to_path_ml = of_path_ml
  let to_path_mli = of_path_mli
  let to_path_c = of_path_c
end

module Gen_file = struct
  module T = struct
    type t =
      { path : Basename.t
      ; out_dir : Out_dir.t
      }

    let to_dyn { path; out_dir } =
      Dyn.record [ "path", Basename.to_dyn path; "out_dir", Out_dir.to_dyn out_dir ]
    ;;

    let equal t { path; out_dir } =
      Basename.equal t.path path && Out_dir.equal t.out_dir out_dir
    ;;

    let compare t { path; out_dir } =
      let open Compare in
      let= () = Basename.compare t.path path in
      Out_dir.compare t.out_dir out_dir
    ;;
  end

  include T
  module Map = Map.Make (T)
  module Set = Set.Make (T)

  let path t = t.path
  let out_dir t = t.out_dir

  let basename_assert_has_one_of_exts basename ~exts =
    if not (List.exists exts ~f:(fun ext -> Basename.has_extension basename ~ext))
    then (
      match exts with
      | [ ext ] ->
        panic
          [ Pp.textf
              "Expected extension to be %s but got file %S."
              ext
              (Basename.to_filename basename)
          ]
      | _ ->
        panic
          [ Pp.textf
              "Expected extension to be among [%s] but got file %S."
              (String.concat ~sep:", " exts)
              (Basename.to_filename basename)
          ])
  ;;

  let make path out_dir ~exts =
    basename_assert_has_one_of_exts path ~exts;
    { path; out_dir }
  ;;

  let ocaml_object_file_exts = [ ".cmx"; ".cmo" ]
  let ocaml_archive_file_exts = [ ".cmxa"; ".cma" ]
  let ocaml_compiled_interface_file_ext = ".cmi"

  let compiled_ocaml_object_file basename =
    make basename Private ~exts:ocaml_object_file_exts
  ;;

  let compiled_ocaml_object_file_public basename =
    make basename Public ~exts:ocaml_object_file_exts
  ;;

  let compiled_c_object_file basename = make basename Private_c ~exts:[ ".o" ]

  let compiled_ocaml_interface_file basename =
    make basename Private ~exts:[ ocaml_compiled_interface_file_ext ]
  ;;

  let compiled_ocaml_interface_file_public basename =
    make basename Public ~exts:[ ocaml_compiled_interface_file_ext ]
  ;;

  let ocaml_archive_file basename = make basename Public ~exts:ocaml_archive_file_exts
  let executable basename = { path = basename; out_dir = Executable }
  let generated_ocaml_src_file basename = make basename Generated_src ~exts:[ ".ml" ]
  let lib_base = Basename.remove_extension Package.lib_root_ml
  let exe_base = Basename.remove_extension Package.exe_root_ml

  let lib_ocaml_object_file compiler_backend =
    let ext = Compiler_backend.ocaml_object_file_ext compiler_backend in
    compiled_ocaml_object_file @@ Basename.add_extension lib_base ~ext
  ;;

  let lib_ocaml_compiled_interface_file =
    compiled_ocaml_interface_file
    @@ Basename.add_extension lib_base ~ext:ocaml_compiled_interface_file_ext
  ;;

  let exe_ocaml_object_file compiler_backend =
    let ext = Compiler_backend.ocaml_object_file_ext compiler_backend in
    compiled_ocaml_object_file @@ Basename.add_extension exe_base ~ext
  ;;

  let lib_ocaml_archive_file compiler_backend =
    let ext = Compiler_backend.ocaml_archive_file_ext compiler_backend in
    ocaml_archive_file @@ Basename.add_extension lib_base ~ext
  ;;

  let lib_archive_file =
    let basename = Basename.add_extension lib_base ~ext:".a" in
    make basename Public ~exts:[ ".a" ]
  ;;

  let compiled_ocaml_object_to_generate_library_lsp_files package_name compiler_backend =
    let package_name_s = Package_name.to_string package_name in
    let ext = Compiler_backend.ocaml_object_file_ext compiler_backend in
    let path = Basename.of_filename package_name_s |> Basename.add_extension ~ext in
    { path; out_dir = Public_for_lsp }
  ;;

  let compiled_ocaml_interface_to_generate_library_lsp_files package_name =
    let package_name_s = Package_name.to_string package_name in
    let path =
      Basename.of_filename package_name_s
      |> Basename.add_extension ~ext:ocaml_compiled_interface_file_ext
    in
    { path; out_dir = Public_for_lsp }
  ;;

  let replace_compiled_ocaml_object_ext_with_cmt t =
    basename_assert_has_one_of_exts t.path ~exts:ocaml_object_file_exts;
    { t with path = Basename.replace_extension t.path ~ext:".cmt" }
  ;;

  let replace_compiled_ocaml_interface_ext_with_cmti t =
    basename_assert_has_one_of_exts t.path ~exts:[ ocaml_compiled_interface_file_ext ];
    { t with path = Basename.replace_extension t.path ~ext:".cmti" }
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

    let cmx_of_cmi (cmi : cmi t) =
      of_path_checked
        (Basename.replace_extension cmi.path ~ext:".cmo")
        Cmx
        ".cmo"
        ~visibility:cmi.visibility
    ;;

    let ml_of_cmi (cmi : cmi t) =
      of_path_checked
        (Basename.replace_extension cmi.path ~ext:".ml")
        Ml
        ".ml"
        ~visibility:cmi.visibility
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
  end

  module Linked = struct
    type _ t =
      | Lib_cmxa : cmxa t
      | Lib_cma : cma t
      | Lib_a : a t
      | Exe_native : Basename.t -> exe_native t
      | Exe_bytecode : Basename.t -> exe_bytecode t

    let lib_cmxa = Lib_cmxa
    let lib_cma = Lib_cma
    let lib_a = Lib_a
    let exe_native name = Exe_native name
    let exe_bytecode name = Exe_bytecode name

    let to_dyn : type a. a t -> Dyn.t = function
      | Lib_cmxa -> Dyn.variant "Lib_cmxa" []
      | Lib_cma -> Dyn.variant "Lib_cma" []
      | Lib_a -> Dyn.variant "Lib_a" []
      | Exe_native path -> Dyn.variant "Exe_native" [ Basename.to_dyn path ]
      | Exe_bytecode path -> Dyn.variant "Exe_bytecode" [ Basename.to_dyn path ]
    ;;

    let equal : type a. a t -> a t -> bool =
      fun a b ->
      match a, b with
      | Lib_cmxa, Lib_cmxa -> true
      | Lib_cma, Lib_cma -> true
      | Lib_a, Lib_a -> true
      | Exe_native a, Exe_native b -> Basename.equal a b
      | Exe_bytecode a, Exe_bytecode b -> Basename.equal a b
    ;;

    let compare : type a. a t -> a t -> int =
      fun a b ->
      match a, b with
      | Lib_cmxa, Lib_cmxa -> 0
      | Lib_cma, Lib_cma -> 0
      | Lib_a, Lib_a -> 0
      | Exe_native a, Exe_native b -> Basename.compare a b
      | Exe_bytecode a, Exe_bytecode b -> Basename.compare a b
    ;;

    let generated_file : type a. a t -> Generated_file.t = function
      | Lib_cmxa -> Generated_file.Linked_library Cmxa
      | Lib_cma -> Generated_file.Linked_library Cma
      | Lib_a -> Generated_file.Linked_library A
      | Exe_native name ->
        Generated_file.Linked_executable (Generated_file.Linked_executable.Native name)
      | Exe_bytecode name ->
        Generated_file.Linked_executable (Generated_file.Linked_executable.Bytecode name)
    ;;

    let path t = generated_file t |> Generated_file.path
  end
end

module Pack = struct
  type t = Package_name.t

  let equal = Package_name.equal
  let compare = Package_name.compare
  let to_dyn = Package_name.to_dyn
  let of_package_name t = t
  let package_name t = t
  let module_name t = Module_name.internal_modules t

  let compiled_ocaml_object_file t =
    Module_name.basename_without_extension (module_name t)
    |> Basename.add_extension ~ext:".cmx"
    |> Gen_file.compiled_ocaml_object_file_public
  ;;
end

module Compile_ocaml_source = struct
  type t =
    { source_input : Src_file.t
    ; compiled_inputs : Gen_file.t list
    ; compiled_object_output : Gen_file.t
    ; interface_output_if_no_matching_mli_is_present : Gen_file.t option
    ; stop_after_typing : bool
    }

  let equal
        t
        { source_input
        ; compiled_inputs
        ; compiled_object_output
        ; interface_output_if_no_matching_mli_is_present
        ; stop_after_typing
        }
    =
    Src_file.equal t.source_input source_input
    && List.equal t.compiled_inputs compiled_inputs ~eq:Gen_file.equal
    && Gen_file.equal t.compiled_object_output compiled_object_output
    && Option.equal
         ~eq:Gen_file.equal
         t.interface_output_if_no_matching_mli_is_present
         interface_output_if_no_matching_mli_is_present
    && Bool.equal t.stop_after_typing stop_after_typing
  ;;

  let compare
        t
        { source_input
        ; compiled_inputs
        ; compiled_object_output
        ; interface_output_if_no_matching_mli_is_present
        ; stop_after_typing
        }
    =
    let open Compare in
    let= () = Src_file.compare t.source_input source_input in
    let= () = List.compare ~cmp:Gen_file.compare t.compiled_inputs compiled_inputs in
    let= () = Gen_file.compare t.compiled_object_output compiled_object_output in
    let= () =
      Option.compare
        ~cmp:Gen_file.compare
        t.interface_output_if_no_matching_mli_is_present
        interface_output_if_no_matching_mli_is_present
    in
    Bool.compare t.stop_after_typing stop_after_typing
  ;;

  let to_dyn
        { source_input
        ; compiled_inputs
        ; compiled_object_output
        ; interface_output_if_no_matching_mli_is_present
        ; stop_after_typing
        }
    =
    Dyn.record
      [ "source_input", Src_file.to_dyn source_input
      ; "compiled_inputs", Dyn.list Gen_file.to_dyn compiled_inputs
      ; "compiled_object_output", Gen_file.to_dyn compiled_object_output
      ; ( "interface_output_if_no_matching_mli_is_present"
        , Dyn.option Gen_file.to_dyn interface_output_if_no_matching_mli_is_present )
      ; "stop_after_typing", Dyn.bool stop_after_typing
      ]
  ;;
end

module Compile_ocaml_interface = struct
  type t =
    { interface_input : Src_file.t
    ; compiled_inputs : Gen_file.t list
    ; compiled_interface_output : Gen_file.t
    ; stop_after_typing : bool
    }

  let equal
        t
        { interface_input; compiled_inputs; compiled_interface_output; stop_after_typing }
    =
    Src_file.equal t.interface_input interface_input
    && List.equal t.compiled_inputs compiled_inputs ~eq:Gen_file.equal
    && Gen_file.equal t.compiled_interface_output compiled_interface_output
    && Bool.equal t.stop_after_typing stop_after_typing
  ;;

  let compare
        t
        { interface_input; compiled_inputs; compiled_interface_output; stop_after_typing }
    =
    let open Compare in
    let= () = Src_file.compare t.interface_input interface_input in
    let= () = List.compare ~cmp:Gen_file.compare t.compiled_inputs compiled_inputs in
    let= () = Gen_file.compare t.compiled_interface_output compiled_interface_output in
    Bool.compare t.stop_after_typing stop_after_typing
  ;;

  let to_dyn
        { interface_input; compiled_inputs; compiled_interface_output; stop_after_typing }
    =
    Dyn.record
      [ "interface_input", Src_file.to_dyn interface_input
      ; "compiled_inputs", Dyn.list Gen_file.to_dyn compiled_inputs
      ; "compiled_interface_output", Gen_file.to_dyn compiled_interface_output
      ; "stop_after_typing", Dyn.bool stop_after_typing
      ]
  ;;
end

module Compile_c_source = struct
  type t =
    { source_input : Src_file.t
    ; object_output : Gen_file.t
    }

  let equal t { source_input; object_output } =
    Src_file.equal t.source_input source_input
    && Gen_file.equal t.object_output object_output
  ;;

  let compare t { source_input; object_output } =
    let open Compare in
    let= () = Src_file.compare t.source_input source_input in
    Gen_file.compare t.object_output object_output
  ;;

  let to_dyn { source_input; object_output } =
    Dyn.record
      [ "source_input", Src_file.to_dyn source_input
      ; "object_output", Gen_file.to_dyn object_output
      ]
  ;;
end

module Pack_library = struct
  type t =
    { compiled_object_inputs : Gen_file.t list
    ; pack : Pack.t
    }

  let equal t { compiled_object_inputs; pack } =
    List.equal ~eq:Gen_file.equal t.compiled_object_inputs compiled_object_inputs
    && Pack.equal t.pack pack
  ;;

  let compare t { compiled_object_inputs; pack } =
    let open Compare in
    let= () =
      List.compare ~cmp:Gen_file.compare t.compiled_object_inputs compiled_object_inputs
    in
    Pack.compare t.pack pack
  ;;

  let to_dyn { compiled_object_inputs; pack } =
    Dyn.record
      [ "compiled_object_inputs", Dyn.list Gen_file.to_dyn compiled_object_inputs
      ; "pack", Pack.to_dyn pack
      ]
  ;;
end

module Generate_public_interface_to_open = struct
  type t = { ml_output : Gen_file.t }

  let equal t { ml_output } = Gen_file.equal t.ml_output ml_output
  let compare t { ml_output } = Gen_file.compare t.ml_output ml_output
  let to_dyn { ml_output } = Dyn.record [ "ml_output", Gen_file.to_dyn ml_output ]
end

module Compile_public_interface_to_open = struct
  type t =
    { generated_source_input : Gen_file.t
    ; internal_modules_pack : Pack.t
    ; compiled_object_output : Gen_file.t
    ; compiled_interface_output : Gen_file.t
    }

  let create ~generated_source_input ~internal_modules_pack =
    let open File.Compiled in
    let basename = Gen_file.path generated_source_input in
    { generated_source_input
    ; internal_modules_pack
    ; compiled_object_output =
        Basename.replace_extension basename ~ext:".cmx"
        |> Gen_file.compiled_ocaml_object_file_public
    ; compiled_interface_output =
        Basename.replace_extension basename ~ext:".cmi"
        |> Gen_file.compiled_ocaml_interface_file_public
    }
  ;;

  let equal
        t
        { generated_source_input
        ; internal_modules_pack
        ; compiled_object_output
        ; compiled_interface_output
        }
    =
    Gen_file.equal t.generated_source_input generated_source_input
    && Pack.equal t.internal_modules_pack internal_modules_pack
    && Gen_file.equal t.compiled_object_output compiled_object_output
    && Gen_file.equal t.compiled_interface_output compiled_interface_output
  ;;

  let compare
        t
        { generated_source_input
        ; internal_modules_pack
        ; compiled_object_output
        ; compiled_interface_output
        }
    =
    let open Compare in
    let= () = Gen_file.compare t.generated_source_input generated_source_input in
    let= () = Pack.compare t.internal_modules_pack internal_modules_pack in
    let= () = Gen_file.compare t.compiled_object_output compiled_object_output in
    Gen_file.compare t.compiled_interface_output compiled_interface_output
  ;;

  let to_dyn
        { generated_source_input
        ; internal_modules_pack
        ; compiled_object_output
        ; compiled_interface_output
        }
    =
    Dyn.record
      [ "generated_source_input", Gen_file.to_dyn generated_source_input
      ; "internal_modules_pack", Pack.to_dyn internal_modules_pack
      ; "compiled_object_output", Gen_file.to_dyn compiled_object_output
      ; "compiled_interface_output", Gen_file.to_dyn compiled_interface_output
      ]
  ;;
end

module Link_library = struct
  type t =
    { compiled_object_inputs : Gen_file.t list
    ; compiled_c_inputs : Gen_file.t list
    ; ocaml_archive_output : Gen_file.t
    ; archive_output : Gen_file.t
    }

  let equal
        t
        { compiled_object_inputs
        ; compiled_c_inputs
        ; ocaml_archive_output
        ; archive_output
        }
    =
    let eq = Gen_file.equal in
    List.equal t.compiled_object_inputs compiled_object_inputs ~eq
    && List.equal t.compiled_c_inputs compiled_c_inputs ~eq
    && eq t.ocaml_archive_output ocaml_archive_output
    && eq t.archive_output archive_output
  ;;

  let compare
        t
        { compiled_object_inputs
        ; compiled_c_inputs
        ; ocaml_archive_output
        ; archive_output
        }
    =
    let cmp = Gen_file.compare in
    let open Compare in
    let= () = List.compare ~cmp t.compiled_object_inputs compiled_object_inputs in
    let= () = List.compare ~cmp t.compiled_c_inputs compiled_c_inputs in
    let= () = Gen_file.compare t.ocaml_archive_output ocaml_archive_output in
    Gen_file.compare t.archive_output archive_output
  ;;

  let to_dyn
        { compiled_object_inputs
        ; compiled_c_inputs
        ; ocaml_archive_output
        ; archive_output
        }
    =
    Dyn.record
      [ "compiled_object_inputs", Dyn.list Gen_file.to_dyn compiled_object_inputs
      ; "compiled_c_inputs", Dyn.list Gen_file.to_dyn compiled_c_inputs
      ; "ocaml_archive_output", Gen_file.to_dyn ocaml_archive_output
      ; "archive_output", Gen_file.to_dyn archive_output
      ]
  ;;

  let of_inputs ~compiled_object_inputs ~compiled_c_inputs =
    { compiled_object_inputs
    ; compiled_c_inputs
    ; ocaml_archive_output = Gen_file.lib_ocaml_archive_file Native
    ; archive_output = Gen_file.lib_archive_file
    }
  ;;
end

module Link_executable = struct
  type t =
    { compiled_object_inputs : Gen_file.t list
    ; compiled_c_inputs : Gen_file.t list
    ; exe_output : Gen_file.t
    }

  let equal t { compiled_object_inputs; compiled_c_inputs; exe_output } =
    let eq = Gen_file.equal in
    List.equal t.compiled_object_inputs compiled_object_inputs ~eq
    && List.equal t.compiled_c_inputs compiled_c_inputs ~eq
    && eq t.exe_output exe_output
  ;;

  let compare t { compiled_object_inputs; compiled_c_inputs; exe_output } =
    let cmp = Gen_file.compare in
    let open Compare in
    let= () = List.compare ~cmp t.compiled_object_inputs compiled_object_inputs in
    let= () = List.compare ~cmp t.compiled_c_inputs compiled_c_inputs in
    cmp t.exe_output exe_output
  ;;

  let to_dyn { compiled_object_inputs; compiled_c_inputs; exe_output } =
    Dyn.record
      [ "compiled_object_inputs", Dyn.list Gen_file.to_dyn compiled_object_inputs
      ; "compiled_c_inputs", Dyn.list Gen_file.to_dyn compiled_c_inputs
      ; "exe_output", Gen_file.to_dyn exe_output
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
  | Compile_ocaml_source { source_input; _ } -> Some source_input
  | Compile_ocaml_interface { interface_input; _ } -> Some interface_input
  | Compile_c_source { source_input; _ } -> Some source_input
  | Pack_library _
  | Generate_public_interface_to_open _
  | Compile_public_interface_to_open _
  | Link_library _
  | Link_executable _ -> None
;;

let generated_inputs t =
  match t with
  | Compile_ocaml_source { compiled_inputs; _ }
  | Compile_ocaml_interface { compiled_inputs; _ } -> compiled_inputs
  | Compile_c_source _ -> []
  | Pack_library { compiled_object_inputs; _ } -> compiled_object_inputs
  | Generate_public_interface_to_open _ -> []
  | Compile_public_interface_to_open { generated_source_input; internal_modules_pack; _ }
    -> [ generated_source_input; Pack.compiled_ocaml_object_file internal_modules_pack ]
  | Link_library { compiled_object_inputs; compiled_c_inputs; _ } ->
    compiled_c_inputs @ compiled_object_inputs
  | Link_executable { compiled_object_inputs; compiled_c_inputs; _ } ->
    compiled_c_inputs @ compiled_object_inputs
;;

let outputs = function
  | Compile_ocaml_source
      { compiled_object_output
      ; interface_output_if_no_matching_mli_is_present
      ; stop_after_typing
      ; _
      } ->
    (if stop_after_typing then [] else [ compiled_object_output ])
    @ [ Gen_file.replace_compiled_ocaml_object_ext_with_cmt compiled_object_output ]
    @ Option.to_list interface_output_if_no_matching_mli_is_present
  | Compile_ocaml_interface { compiled_interface_output; _ } ->
    [ compiled_interface_output
    ; Gen_file.replace_compiled_ocaml_interface_ext_with_cmti compiled_interface_output
    ]
  | Compile_c_source { object_output; _ } -> [ object_output ]
  | Pack_library { pack; _ } -> [ Pack.compiled_ocaml_object_file pack ]
  | Generate_public_interface_to_open { ml_output } -> [ ml_output ]
  | Compile_public_interface_to_open { compiled_object_output; _ } ->
    [ compiled_object_output ]
  | Link_library { ocaml_archive_output; archive_output; _ } ->
    [ ocaml_archive_output; archive_output ]
  | Link_executable { exe_output; _ } -> [ exe_output ]
;;
