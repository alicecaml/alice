open! Alice_stdlib
open Alice_hierarchy
open Alice_package
open Alice_ocaml_compiler

module Build_node = struct
  module Name = Typed_op.Generated_file

  (* For the sake of simplicity, each node in the build graph corresponds to a
     single file. Most build operations produce multiple files, so the same
     operation may be associated with multiple nodes in the graph. When
     evaluating the build graph, care should be taken to not run the same
     operation multiple times. *)
  type t =
    { artifact : Name.t (** A single file produced by the associated operation. *)
    ; op : Typed_op.t
      (** An operation which creates [artifact], but which may also create other files. *)
    }

  let to_dyn { artifact; op } =
    Dyn.record [ "artifact", Name.to_dyn artifact; "op", Typed_op.to_dyn op ]
  ;;

  let equal t { artifact; op } = Name.equal t.artifact artifact && Typed_op.equal t.op op
  let name { artifact; _ } = artifact
  let op { op; _ } = op
  let dep_names t = Typed_op.generated_inputs t.op |> Name.Set.of_list

  let show_name name =
    let path = Alice_ui.basename_to_string (Name.path name) in
    match (name : Typed_op.Generated_file.t) with
    | Compiled compiled ->
      (match Typed_op.Generated_file.Compiled.visibility compiled with
       | Public_for_lsp -> sprintf "%s (for lsp)" path
       | _ -> path)
    | _ -> path
  ;;

  let show t = show_name t.artifact
end

module Build_dag = struct
  include Alice_dag.Make (Build_node)

  module Staging = struct
    include Staging

    let add_op t op =
      List.fold_left (Typed_op.outputs op) ~init:t ~f:(fun t artifact ->
        let build_node = { Build_node.artifact; op } in
        match add t artifact build_node with
        | Ok t -> t
        | Error (`Conflict _) ->
          Alice_error.panic
            [ Pp.textf "Conflicting origins for file: %s" (Build_node.show_name artifact)
            ])
    ;;

    let finalize t =
      match finalize t with
      | Ok t -> t
      | Error (`Dangling dangling) ->
        Alice_error.panic
          [ Pp.textf "No rule to build: %s" (Build_node.show_name dangling) ]
      | Error (`Cycle cycle) ->
        Alice_error.panic
          ([ Pp.text "Dependency cycle:"; Pp.newline ]
           @ List.concat_map cycle ~f:(fun file ->
             [ Pp.textf " - %s" (Build_node.show_name file); Pp.newline ]))
    ;;
  end

  let of_ops ops =
    List.fold_left ops ~init:Staging.empty ~f:Staging.add_op |> Staging.finalize
  ;;

  let traverse t ~output = traverse t ~name:output

  (* Returns the cmx files in build order which must be built before the files
     listed in [starts], including the files in [starts]. *)
  let cmx_files_in_build_order t ~start =
    let open Typed_op in
    transitive_closure_in_dependency_order t ~start ~include_start:true
    |> List.filter_map ~f:(fun (node : Build_node.t) ->
      match node.op with
      | Compile_source { cmx_output; _ } ->
        if Generated_file.equal node.artifact (File.Compiled.generated_file cmx_output)
        then
          (* Multiple artifacts are built from the same command, but here we're
             only interested in the cmx artifact. *)
          Some cmx_output
        else None
      | _ -> None)
  ;;

  (* The cmx files needed to build the library cmx target in build order. *)
  let cmx_files_in_build_order_for_lib t =
    cmx_files_in_build_order
      t
      ~start:(Typed_op.File.Compiled.generated_file Typed_op.File.Compiled.lib_cmx)
  ;;

  (* The cmx files needed to build the executable cmx target in build order. *)
  let cmx_files_in_build_order_for_exe t =
    cmx_files_in_build_order
      t
      ~start:(Typed_op.File.Compiled.generated_file Typed_op.File.Compiled.exe_cmx)
  ;;
end

module Build_plan = struct
  include Build_dag.Traverse

  let op t = (node t).op
  let source_input t = Typed_op.source_input (op t)
  let generated_inputs t = Typed_op.generated_inputs (op t)
  let outputs t = Typed_op.outputs (op t) |> Typed_op.Generated_file.Set.of_list

  let transitive_closure_outputs t =
    transitive_closure_in_dependency_order t
    |> List.map ~f:Build_node.name
    |> Typed_op.Generated_file.Set.of_list
  ;;
end

let compilation_ops dir package_id build_dir ocaml_compiler io_ctx =
  let ocamldep_cache = Ocamldep_cache.load build_dir package_id in
  let deps_key_value_pairs =
    Dir_non_root.contents dir
    |> List.filter ~f:(fun file ->
      File_non_root.is_regular_or_link file
      && (Absolute_path.has_extension file.path ~ext:".ml"
          || Absolute_path.has_extension file.path ~ext:".mli"))
    |> List.sort ~cmp:File_non_root.compare_by_path
    |> List.map ~f:(fun (file : File_non_root.t) ->
      fun () ->
      ( file.path
      , Ocamldep_cache.get_deps
          ocamldep_cache
          io_ctx
          ocaml_compiler
          ~source_path:file.path ))
    |> Alice_io.Eio_fiber.all_values
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

let lsp_ops build_dag_compilation_only package =
  let open Typed_op in
  let lib_cmx_plan =
    Build_dag.traverse build_dag_compilation_only ~output:Typed_op.Generated_file.lib_cmx
  in
  let package_name_s = Package_name.to_string (Package.name package) in
  let compile_source =
    match Build_plan.op lib_cmx_plan with
    | Compile_source
        { source_input
        ; compiled_inputs
        ; cmx_output
        ; interface_output_if_no_matching_mli_is_present
        ; stop_after_typing = _
        } ->
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
           node. When building the cmt file we'll open this package own
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
    | other ->
      Alice_error.panic
        [ Pp.textf
            "Expected library cmx file to be generated by a [Compile_source] op, but \
             instead op is %s"
            (Typed_op.to_dyn other |> Dyn.to_string)
        ]
  in
  let compile_interface =
    match compile_source.interface_output_if_no_matching_mli_is_present with
    | Some _ ->
      (* .cmi file is produced by compiling the source *)
      None
    | None ->
      let lib_cmi_plan =
        Build_dag.traverse
          build_dag_compilation_only
          ~output:Typed_op.Generated_file.lib_cmi
      in
      (match Build_plan.op lib_cmi_plan with
       | Compile_interface
           { interface_input; compiled_inputs; cmi_output; stop_after_typing = _ } ->
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
           (Compile_interface
              { interface_input; compiled_inputs; cmi_output; stop_after_typing = true })
       | other ->
         Alice_error.panic
           [ Pp.textf
               "Expected library cmx file to be generated by a [Compile_source] op, but \
                instead op is %s"
               (Typed_op.to_dyn other |> Dyn.to_string)
           ])
  in
  [ Compile_source compile_source ] @ Option.to_list compile_interface
;;

type ('exe, 'lib) t =
  { build_dag : Build_dag.t
  ; exe_file : Typed_op.File_type.exe Typed_op.File.Linked.t
  ; package_typed : ('exe, 'lib) Package.Typed.t
  }

let to_dyn { build_dag; exe_file; package_typed } =
  Dyn.record
    [ "build_dag", Build_dag.to_dyn build_dag
    ; "exe_file", Typed_op.File.Linked.to_dyn exe_file
    ; "package_typed", Package.Typed.to_dyn package_typed
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
      Build_dag.cmx_files_in_build_order_for_lib build_dag_compilation_only
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
      Build_dag.cmx_files_in_build_order_for_exe build_dag_compilation_only
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
    | Exe_only -> []
    | Lib_only | Exe_and_lib -> lsp_ops build_dag_compilation_only package
  in
  let build_dag =
    List.fold_left
      (link_ops @ lsp_ops)
      ~init:(Build_dag.restage build_dag_compilation_only)
      ~f:Build_dag.Staging.add_op
    |> Build_dag.Staging.finalize
  in
  { build_dag; exe_file; package_typed }
;;

let plan_exe ({ build_dag; exe_file; _ } : (Type_bool.true_t, _) t) =
  Build_dag.traverse build_dag ~output:(Typed_op.File.Linked.generated_file exe_file)
;;

let plan_lib ({ build_dag; _ } : (_, Type_bool.true_t) t) =
  Build_dag.traverse build_dag ~output:(Typed_op.Generated_file.Linked_library Cmxa)
;;

let plan_lsp ({ build_dag; package_typed; _ } : (_, Type_bool.true_t) t) =
  Build_dag.traverse
    build_dag
    ~output:(Typed_op.Generated_file.cmt_for_lsp (Package.Typed.name package_typed))
;;

let dot t =
  List.fold_left
    (Build_dag.nodes t.build_dag)
    ~init:(Build_dag.to_string_graph t.build_dag)
    ~f:(fun string_graph node ->
      match Typed_op.source_input (Build_node.op node) with
      | None -> string_graph
      | Some source_path_abs ->
        let source_basename = Absolute_path.basename source_path_abs in
        let source_path_string = Basename.to_filename source_basename in
        String.Map.update string_graph ~key:(Build_node.show node) ~f:(function
          | None -> Some (String.Set.singleton source_path_string)
          | Some existing -> Some (String.Set.add source_path_string existing)))
  |> Alice_graphviz.dot_src_of_string_graph
;;
