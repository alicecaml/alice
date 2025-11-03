open! Alice_stdlib
open Alice_hierarchy
open Alice_package

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

  let dep_names t =
    Typed_op.compiled_inputs t.op
    |> List.map ~f:(fun compiled -> Typed_op.Generated_file.Compiled compiled)
    |> Name.Set.of_list
  ;;

  let show_name name = Alice_ui.basename_to_string (Name.path name)
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
end

module Build_plan = struct
  include Build_dag.Traverse

  let op t = (node t).op
  let source_input t = Typed_op.source_input (op t)
  let compiled_inputs t = Typed_op.compiled_inputs (op t)
  let outputs t = Typed_op.outputs (op t) |> Typed_op.Generated_file.Set.of_list
end

let compilation_ops dir package_id build_dir env ocamlopt =
  let ocamldep_cache = Ocamldep_cache.load build_dir package_id in
  let deps =
    Dir_non_root.contents dir
    |> List.filter ~f:(fun file ->
      File_non_root.is_regular_or_link file
      && (Absolute_path.has_extension file.path ~ext:".ml"
          || Absolute_path.has_extension file.path ~ext:".mli"))
    |> List.sort ~cmp:File_non_root.compare_by_path
    |> List.map ~f:(fun (file : File_non_root.t) ->
      ( file.path
      , Ocamldep_cache.get_deps ocamldep_cache env ocamlopt ~source_path:file.path ))
    |> Absolute_path.Non_root_map.of_list_exn
  in
  Ocamldep_cache.store ocamldep_cache deps;
  Absolute_path.Non_root_map.to_list deps
  |> List.map ~f:(fun (source_path, (deps : Alice_ocamldep.Deps.t)) ->
    let open Typed_op in
    let open Alice_error in
    match File.Source.of_path_by_extension source_path with
    | Error (`Unknown_extension _) ->
      panic
        [ Pp.textf
            "Tried to treat %S as source path but it has an unrecognized extension."
            (Alice_ui.absolute_path_to_string source_path)
        ]
    | Ok (`Ml direct_input) ->
      let indirect_inputs =
        List.map deps.inputs ~f:(fun dep ->
          match File.Compiled.of_path_by_extension_infer_role_from_name dep with
          | Ok (`Cmx cmx) -> `Cmx cmx
          | Ok (`Cmi cmi) -> `Cmi cmi
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
      let source_file = Absolute_path.basename source_path in
      let direct_output =
        Basename.replace_extension source_file ~ext:".cmx"
        |> File.Compiled.cmx_infer_role_from_name
      in
      let indirect_output =
        Basename.replace_extension source_file ~ext:".o"
        |> File.Compiled.o_infer_role_from_name
      in
      let matching_mli_file = Absolute_path.replace_extension source_path ~ext:".mli" in
      let interface_output_if_no_matching_mli_is_present =
        if Dir_non_root.contains dir matching_mli_file
        then None
        else
          Some
            (Basename.replace_extension source_file ~ext:".cmi"
             |> File.Compiled.cmi_infer_role_from_name)
      in
      Compile_source
        { direct_input
        ; indirect_inputs
        ; direct_output
        ; indirect_output
        ; interface_output_if_no_matching_mli_is_present
        }
    | Ok (`Mli direct_input) ->
      let indirect_inputs =
        List.map deps.inputs ~f:(fun dep ->
          match File.Compiled.of_path_by_extension_infer_role_from_name dep with
          | Ok (`Cmi cmi) -> cmi
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
      let direct_output =
        Absolute_path.basename source_path
        |> Basename.replace_extension ~ext:".cmi"
        |> File.Compiled.cmi_infer_role_from_name
      in
      Compile_interface { direct_input; indirect_inputs; direct_output })
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

let cmx_files_in_build_order build_dag_compilation_only =
  let open Typed_op in
  let rec loop to_visit seen acc =
    match to_visit with
    | [] -> acc
    | x :: xs ->
      (match Build_plan.op x with
       | Compile_source { direct_output; _ } ->
         let deps = Build_plan.deps x in
         let to_visit = xs @ deps in
         let generated_file = File.Compiled.generated_file direct_output in
         if Generated_file.Set.mem generated_file seen
         then loop to_visit seen acc
         else (
           let acc = direct_output :: acc in
           let seen = Generated_file.Set.add generated_file seen in
           loop to_visit seen acc)
       | _ -> loop xs seen acc)
  in
  let root_traverses =
    Build_dag.roots build_dag_compilation_only
    |> List.filter_map ~f:(fun root ->
      match
        Build_node.name root |> Generated_file.path |> Basename.has_extension ~ext:".cmx"
      with
      | false -> None
      | true ->
        let traverse =
          Build_dag.traverse build_dag_compilation_only ~output:(Build_node.name root)
          |> Option.get
        in
        Some traverse)
  in
  loop root_traverses Generated_file.Set.empty []
;;

let create
  : type exe lib.
    (exe, lib) Package.Typed.t
    -> Build_dir.t
    -> Alice_env.Os_type.t
    -> Alice_env.Env.t
    -> Alice_which.Ocamlopt.t
    -> (exe, lib) t
  =
  fun package_typed build_dir os_type env ocamlopt ->
  let open Typed_op in
  let package = Package.Typed.package package_typed in
  let src_dir = Package.src_dir_exn package in
  let compilation_ops =
    compilation_ops src_dir (Package.id package) build_dir env ocamlopt
  in
  let build_dag_compilation_only = Build_dag.of_ops compilation_ops in
  let cmx_files = cmx_files_in_build_order build_dag_compilation_only in
  let link_library () = Link_library (Link_library.of_inputs cmx_files) in
  let exe_file =
    let exe_name =
      Basename.of_filename (Package.name package |> Package_name.to_string)
      |> Alice_env.Os_type.basename_add_exe_extension_on_windows os_type
    in
    File.Linked.exe exe_name
  in
  let link_executable () =
    Link_executable { direct_output = exe_file; direct_inputs = cmx_files }
  in
  let link_ops =
    match Package.Typed.type_ package_typed with
    | Exe_only -> [ link_executable () ]
    | Lib_only -> [ link_library () ]
    | Exe_and_lib -> [ link_library (); link_executable () ]
  in
  let build_dag =
    List.fold_left
      link_ops
      ~init:(Build_dag.restage build_dag_compilation_only)
      ~f:Build_dag.Staging.add_op
    |> Build_dag.Staging.finalize
  in
  { build_dag; exe_file; package_typed }
;;

let plan_exe ({ build_dag; exe_file; _ } : (Type_bool.true_t, _) t) =
  Build_dag.traverse build_dag ~output:(Typed_op.File.Linked.generated_file exe_file)
  |> Option.get
;;

let plan_lib ({ build_dag; _ } : (_, Type_bool.true_t) t) =
  Build_dag.traverse build_dag ~output:(Typed_op.Generated_file.Linked_library Cmxa)
  |> Option.get
;;

let create_exe_plan package_typed build_dir os_type env ocamlopt =
  create package_typed build_dir os_type env ocamlopt |> plan_exe
;;

let create_lib_plan package_typed build_dir os_type env ocamlopt =
  create package_typed build_dir os_type env ocamlopt |> plan_lib
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
