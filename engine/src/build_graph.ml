open! Alice_stdlib
open Alice_hierarchy
open Alice_package
open Alice_ocaml_compiler

module Build_dag = struct
  include Alice_dag.Make (Typed_op)

  type nonrec t = unit t

  let to_dyn = to_dyn Dyn.unit

  let of_ops ops =
    let ops_by_output_files =
      List.concat_map ops ~f:(fun op ->
        List.map (Typed_op.outputs op) ~f:(fun output -> output, op))
      |> Typed_op.Generated_file.Map.of_list_exn
    in
    let op_deps op =
      Typed_op.generated_inputs op
      |> List.map ~f:(fun input ->
        Typed_op.Generated_file.Map.find input ops_by_output_files)
    in
    List.fold_left ops ~init:Staging.empty ~f:(fun acc op ->
      Staging.add_or_panic acc op () ~eq:Unit.equal ~child_names:(op_deps op))
    |> Staging.finalize_or_panic
  ;;

  (* Returns the cmx files in build order produced by [node] and all the nodes
     which [node] transitively depends on. *)
  let cmx_files_in_build_order node =
    let open Typed_op in
    Node.transitive_closure_in_child_first_order node ~include_start:true
    |> List.filter_map ~f:(fun node ->
      match Node.name node with
      | Compile_source { cmx_output; _ } -> Some cmx_output
      | _ -> None)
  ;;

  let link_library_op_node_or_panic t =
    match
      all_nodes t
      |> List.filter_map ~f:(fun node ->
        match Node.name node with
        | Typed_op.Link_library _ -> Some node
        | _ -> None)
    with
    | [] -> Alice_error.panic [ Pp.text "No ops would link library!" ]
    | [ node ] -> node
    | _multiple -> Alice_error.panic [ Pp.text "Multiple ops would link library!" ]
  ;;

  let link_executable_op_node_or_panic t =
    match
      all_nodes t
      |> List.filter_map ~f:(fun node ->
        match Node.name node with
        | Typed_op.Link_executable _ -> Some node
        | _ -> None)
    with
    | [] -> Alice_error.panic [ Pp.text "No ops would link executable!" ]
    | [ node ] -> node
    | _multiple -> Alice_error.panic [ Pp.text "Multiple ops would link executable!" ]
  ;;

  let compile_library_cmx_node_or_panic t =
    match
      all_nodes t
      |> List.filter_map ~f:(fun node ->
        match Node.name node with
        | Compile_source { cmx_output; _ }
          when Typed_op.File.Compiled.equal cmx_output Typed_op.File.Compiled.lib_cmx ->
          Some node
        | _ -> None)
    with
    | [] -> Alice_error.panic [ Pp.text "No ops would compile library cmx!" ]
    | [ node ] -> node
    | _multiple -> Alice_error.panic [ Pp.text "Multiple ops would compile library cmx!" ]
  ;;

  let compile_executable_cmx_node_or_panic t =
    match
      all_nodes t
      |> List.filter_map ~f:(fun node ->
        match Node.name node with
        | Compile_source { cmx_output; _ }
          when Typed_op.File.Compiled.equal cmx_output Typed_op.File.Compiled.exe_cmx ->
          Some node
        | _ -> None)
    with
    | [] -> Alice_error.panic [ Pp.text "No ops would compile executable cmx!" ]
    | [ node ] -> node
    | _multiple ->
      Alice_error.panic [ Pp.text "Multiple ops would compile executable cmx!" ]
  ;;

  let library_cmx_compile_source_or_panic t =
    match
      all_nodes t
      |> List.filter_map ~f:(fun node ->
        match Node.name node with
        | Compile_source ({ cmx_output; _ } as compile_source)
          when Typed_op.File.Compiled.equal cmx_output Typed_op.File.Compiled.lib_cmx ->
          Some compile_source
        | _ -> None)
    with
    | [] -> Alice_error.panic [ Pp.text "No ops would compile library cmx!" ]
    | [ compile_source ] -> compile_source
    | _multiple -> Alice_error.panic [ Pp.text "Multiple ops would compile library cmx!" ]
  ;;

  let library_cmi_compile_interface_or_panic t =
    match
      all_nodes t
      |> List.filter_map ~f:(fun node ->
        match Node.name node with
        | Compile_interface ({ cmi_output; _ } as compile_interface)
          when Typed_op.File.Compiled.equal cmi_output Typed_op.File.Compiled.lib_cmi ->
          Some compile_interface
        | _ -> None)
    with
    | [] -> Alice_error.panic [ Pp.text "No ops would compile library cmi!" ]
    | [ compile_interface ] -> compile_interface
    | _multiple -> Alice_error.panic [ Pp.text "Multiple ops would compile library cmi!" ]
  ;;

  (* The cmx files needed to build the library cmx target in build order. *)
  let cmx_files_in_build_order_for_library t =
    cmx_files_in_build_order (compile_library_cmx_node_or_panic t)
  ;;

  (* The cmx files needed to build the executable cmx target in build order. *)
  let cmx_files_in_build_order_for_executable t =
    cmx_files_in_build_order (compile_executable_cmx_node_or_panic t)
  ;;
end

module Build_plan = struct
  include Build_dag.Node

  type nonrec t = unit t

  let deps t = children t
  let op t = name t
  let source_input t = Typed_op.source_input (op t)
  let generated_inputs t = Typed_op.generated_inputs (op t)
  let outputs t = Typed_op.outputs (op t) |> Typed_op.Generated_file.Set.of_list

  let transitive_closure_outputs t =
    transitive_closure_in_child_first_order t ~include_start:true
    |> List.map ~f:outputs
    |> Typed_op.Generated_file.Set.union_all
  ;;
end

let compilation_ops dir package_id build_dir ocaml_compiler (io_ctx : _ Alice_io.Io_ctx.t)
  =
  let ocamldep_cache = Ocamldep_cache.load build_dir package_id in
  let source_paths =
    Dir_non_root.contents dir
    |> List.filter ~f:(fun file ->
      File_non_root.is_regular_or_link file
      && (Absolute_path.has_extension file.path ~ext:".ml"
          || Absolute_path.has_extension file.path ~ext:".mli"))
    |> List.map ~f:(fun (file : File_non_root.t) -> file.path)
  in
  let deps_key_value_pairs =
    Ocamldep_cache.get_deps_batch
      ocamldep_cache
      ocaml_compiler
      io_ctx.num_jobs
      ~source_paths
  in
  let deps = Absolute_path.Non_root_map.of_list_exn deps_key_value_pairs in
  Ocamldep_cache.store ocamldep_cache deps;
  Absolute_path.Non_root_map.to_list deps
  |> List.map ~f:(fun (source_path, (deps : Ocaml_compiler.Deps.t)) ->
    let open Typed_op in
    let open Alice_error in
    match File.Source.of_path_by_extension source_path with
    | Error (`Unknown_extension _) ->
      panic
        [ Pp.textf
            "Tried to treat %S as source path but it has an unrecognized extension."
            (Alice_ui.absolute_path_to_string source_path)
        ]
    | Ok (`Ml source_input) ->
      let compiled_inputs =
        List.map deps.inputs ~f:(fun dep ->
          match File.Compiled.of_path_by_extension_private dep with
          | Ok (`Cmx cmx) -> File.Compiled.generated_file_compiled cmx
          | Ok (`Cmi cmi) -> File.Compiled.generated_file_compiled cmi
          | Ok _ ->
            panic
              [ Pp.textf
                  "Running ocamldep on %S produced build input %S whose extension is \
                   unexpected (expected either \".cmx\" or \".cmi\")."
                  (Alice_ui.absolute_path_to_string source_path)
                  (Basename.to_filename dep)
              ]
          | Error (`Unknown_extension _) ->
            panic
              [ Pp.textf
                  "Running ocamldep on %S produced build input %S whose extension is \
                   unrecognized."
                  (Alice_ui.absolute_path_to_string source_path)
                  (Basename.to_filename dep)
              ])
      in
      let source_base_name = Absolute_path.basename source_path in
      let cmx_output =
        Basename.replace_extension source_base_name ~ext:".cmx"
        |> File.Compiled.cmx_private
      in
      let matching_mli_file = Absolute_path.replace_extension source_path ~ext:".mli" in
      let interface_output_if_no_matching_mli_is_present =
        if Dir_non_root.contains dir matching_mli_file
        then None
        else
          Some
            (Basename.replace_extension source_base_name ~ext:".cmi"
             |> File.Compiled.cmi_private)
      in
      Compile_source
        { source_input
        ; compiled_inputs
        ; cmx_output
        ; interface_output_if_no_matching_mli_is_present
        ; stop_after_typing = false
        }
    | Ok (`Mli interface_input) ->
      let compiled_inputs =
        List.map deps.inputs ~f:(fun dep ->
          match File.Compiled.of_path_by_extension_private dep with
          | Ok (`Cmx cmx) -> File.Compiled.generated_file_compiled cmx
          | Ok (`Cmi cmi) -> File.Compiled.generated_file_compiled cmi
          | Ok _ ->
            panic
              [ Pp.textf
                  "Running ocamldep on %S produced build input %S whose extension is \
                   unexpected (expected either \".cmi\")."
                  (Alice_ui.absolute_path_to_string source_path)
                  (Basename.to_filename dep)
              ]
          | Error (`Unknown_extension _) ->
            panic
              [ Pp.textf
                  "Running ocamldep on %S produced build input %S whose extension is \
                   unrecognized."
                  (Alice_ui.absolute_path_to_string source_path)
                  (Basename.to_filename dep)
              ])
      in
      let cmi_output =
        Absolute_path.basename source_path
        |> Basename.replace_extension ~ext:".cmi"
        |> File.Compiled.cmi_private
      in
      Compile_interface
        { interface_input; compiled_inputs; cmi_output; stop_after_typing = false })
;;

type lsp_ops =
  { lsp_ops_compile_source : Typed_op.Compile_source.t
  ; lsp_ops_compile_interface : Typed_op.Compile_interface.t option
  }

let lsp_ops build_dag_compilation_only package =
  let open Typed_op in
  let package_name_s = Package_name.to_string (Package.name package) in
  let compile_source =
    let { Compile_source.source_input
        ; compiled_inputs
        ; cmx_output
        ; interface_output_if_no_matching_mli_is_present
        ; stop_after_typing = _
        }
      =
      Build_dag.library_cmx_compile_source_or_panic build_dag_compilation_only
    in
    let cmx_output =
      Typed_op.File.Compiled.rename
        cmx_output
        ~name_without_extension:package_name_s
        Public_for_lsp
    in
    let interface_output_if_no_matching_mli_is_present =
      Option.map interface_output_if_no_matching_mli_is_present ~f:(fun cmi_output ->
        Typed_op.File.Compiled.rename
          cmi_output
          ~name_without_extension:package_name_s
          Public_for_lsp)
    in
    let compiled_inputs =
      List.map compiled_inputs ~f:(fun input ->
        if
          Typed_op.Generated_file.Compiled.equal
            input
            Typed_op.Generated_file.Compiled.lib_cmi
        then
          (* If the package has a lib.mli file then lib.cmx will depend
             on lib.cmi. Swap the dependency out for <package>.cmi here. *)
          Generated_file.Compiled.rename
            input
            ~name_without_extension:package_name_s
            Public_for_lsp
        else input)
    in
    let compiled_inputs =
      let pack_output =
        let pack = Typed_op.Pack.of_package_name (Package.name package) in
        Typed_op.Pack.cmx_file pack |> Typed_op.File.Compiled.generated_file_compiled
      in
      (* Add the package's internal modules pack to the dependencies of this
         node. When building the cmt file we'll open this package's own
         internal modules pack to handle the situation where there's a file
         in the package with the same name as the package. In this situation
         there's a <package>.cmx in the package's private build directory, and
         this seems to confuse the compiler when generating a file with the same
         name in the public_for_lsp build directory. *)
      pack_output :: compiled_inputs
    in
    { Compile_source.source_input
    ; compiled_inputs
    ; cmx_output
    ; interface_output_if_no_matching_mli_is_present
    ; stop_after_typing = true
    }
  in
  let compile_interface =
    match compile_source.interface_output_if_no_matching_mli_is_present with
    | Some _ ->
      (* .cmi file is produced by compiling the source *)
      None
    | None ->
      let { Compile_interface.interface_input
          ; compiled_inputs
          ; cmi_output
          ; stop_after_typing = _
          }
        =
        Build_dag.library_cmi_compile_interface_or_panic build_dag_compilation_only
      in
      let compiled_inputs =
        let pack_output =
          let pack = Typed_op.Pack.of_package_name (Package.name package) in
          Typed_op.Pack.cmx_file pack |> Typed_op.File.Compiled.generated_file_compiled
        in
        (* Add the package's internal modules pack to the dependencies of this
           node. *)
        pack_output :: compiled_inputs
      in
      let cmi_output =
        Typed_op.File.Compiled.rename
          cmi_output
          ~name_without_extension:package_name_s
          Public_for_lsp
      in
      Some
        { Compile_interface.interface_input
        ; compiled_inputs
        ; cmi_output
        ; stop_after_typing = true
        }
  in
  { lsp_ops_compile_source = compile_source
  ; lsp_ops_compile_interface = compile_interface
  }
;;

type ('exe, 'lib) t =
  { build_dag : Build_dag.t
  ; package_typed : ('exe, 'lib) Package.Typed.t
  ; lsp_ops : lsp_ops option
  }

let to_dyn { build_dag; package_typed; lsp_ops } =
  Dyn.record
    [ "build_dag", Build_dag.to_dyn build_dag
    ; "package_typed", Package.Typed.to_dyn package_typed
    ; ( "lsp_ops"
      , Dyn.option
          (fun { lsp_ops_compile_source; lsp_ops_compile_interface } ->
             Dyn.record
               [ ( "lsp_ops_compile_source"
                 , Typed_op.Compile_source.to_dyn lsp_ops_compile_source )
               ; ( "lsp_ops_compile_interface"
                 , Dyn.option Typed_op.Compile_interface.to_dyn lsp_ops_compile_interface
                 )
               ])
          lsp_ops )
    ]
;;

let create
  : type exe lib.
    (exe, lib) Package.Typed.t
    -> Build_dir.t
    -> Alice_env.Os_type.t
    -> Ocaml_compiler.t
    -> _ Alice_io.Io_ctx.t
    -> (exe, lib) t
  =
  fun package_typed build_dir os_type ocaml_compiler io_ctx ->
  let open Typed_op in
  let package = Package.Typed.package package_typed in
  let src_dir = Package.src_dir_exn package in
  let compilation_ops =
    compilation_ops src_dir (Package.id package) build_dir ocaml_compiler io_ctx
  in
  let build_dag_compilation_only = Build_dag.of_ops compilation_ops in
  let link_library () =
    let cmx_files =
      Build_dag.cmx_files_in_build_order_for_library build_dag_compilation_only
    in
    let pack = Typed_op.Pack.of_package_name (Package.name package) in
    let pack_op = Pack_library { cmx_inputs = cmx_files; pack } in
    let public_interface_to_open_ml =
      Module_name.public_interface_to_open (Package.name package)
      |> Module_name.basename_without_extension
      |> Basename.add_extension ~ext:".ml"
      |> File.Generated_source.ml
    in
    let generate_public_interface_to_open_op =
      Generate_public_interface_to_open { ml_output = public_interface_to_open_ml }
    in
    let compile_public_interface_to_open =
      Compile_public_interface_to_open.create
        ~generated_source_input:public_interface_to_open_ml
        ~internal_modules_pack:pack
    in
    let compile_public_interface_to_open_op =
      Compile_public_interface_to_open compile_public_interface_to_open
    in
    let link_library_op =
      Link_library
        (Link_library.of_inputs
           [ Typed_op.Pack.cmx_file pack; compile_public_interface_to_open.cmx_output ])
    in
    [ pack_op
    ; generate_public_interface_to_open_op
    ; compile_public_interface_to_open_op
    ; link_library_op
    ]
  in
  let exe_file =
    let exe_name =
      Basename.of_filename (Package.name package |> Package_name.to_string)
      |> Alice_env.Os_type.basename_add_exe_extension_on_windows os_type
    in
    File.Linked.exe exe_name
  in
  let link_executable () =
    let cmx_files =
      Build_dag.cmx_files_in_build_order_for_executable build_dag_compilation_only
    in
    [ Link_executable { exe_output = exe_file; cmx_inputs = cmx_files } ]
  in
  let link_ops =
    match Package.Typed.type_ package_typed with
    | Exe_only -> link_executable ()
    | Lib_only -> link_library ()
    | Exe_and_lib -> link_library () @ link_executable ()
  in
  let lsp_ops =
    match Package.Typed.type_ package_typed with
    | Exe_only -> None
    | Lib_only | Exe_and_lib -> Some (lsp_ops build_dag_compilation_only package)
  in
  let build_dag =
    let lsp_ops =
      match lsp_ops with
      | None -> []
      | Some { lsp_ops_compile_source; lsp_ops_compile_interface = None } ->
        [ Compile_source lsp_ops_compile_source ]
      | Some
          { lsp_ops_compile_source
          ; lsp_ops_compile_interface = Some lsp_ops_compile_interface
          } ->
        [ Compile_source lsp_ops_compile_source
        ; Compile_interface lsp_ops_compile_interface
        ]
    in
    Build_dag.of_ops (compilation_ops @ link_ops @ lsp_ops)
  in
  { build_dag; package_typed; lsp_ops }
;;

let plan_exe ({ build_dag; _ } : (Type_bool.true_t, _) t) =
  Build_dag.link_executable_op_node_or_panic build_dag
;;

let plan_lib ({ build_dag; _ } : (_, Type_bool.true_t) t) =
  Build_dag.link_library_op_node_or_panic build_dag
;;

let plan_lsp ({ build_dag; lsp_ops; _ } : (_, Type_bool.true_t) t) =
  let lsp_ops = Option.get lsp_ops in
  Build_dag.get_node build_dag ~name:(Compile_source lsp_ops.lsp_ops_compile_source)
;;

let dot { build_dag; _ } =
  let generated_file_to_string (generated_file : Typed_op.Generated_file.t) =
    let path =
      Alice_ui.basename_to_string (Typed_op.Generated_file.path generated_file)
    in
    match generated_file with
    | Compiled compiled ->
      (match Typed_op.Generated_file.Compiled.visibility compiled with
       | Public_for_lsp -> sprintf "%s (for lsp)" path
       | _ -> path)
    | _ -> path
  in
  Build_dag.all_nodes build_dag
  |> List.fold_left ~init:String.Map.empty ~f:(fun acc node ->
    let op = Build_plan.op node in
    let inputs =
      (Typed_op.generated_inputs op |> List.map ~f:generated_file_to_string)
      @ (Typed_op.source_input op
         |> Option.map ~f:(fun path ->
           Absolute_path.basename path |> Basename.to_filename)
         |> Option.to_list)
      |> String.Set.of_list
    in
    let outputs = Typed_op.outputs op |> List.map ~f:generated_file_to_string in
    List.fold_left outputs ~init:acc ~f:(fun acc output ->
      String.Map.update acc ~key:output ~f:(function
        | None -> Some inputs
        | Some existing -> Some (String.Set.union existing inputs))))
  |> Alice_graphviz.dot_src_of_string_graph
;;
