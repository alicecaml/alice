open! Alice_stdlib
open Alice_hierarchy
open Alice_error
open Alice_ocaml_toolchain
open Alice_package

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

let src_input = function
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
