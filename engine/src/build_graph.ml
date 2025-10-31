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
  let name t = t.artifact

  let dep_names t =
    Typed_op.compiled_inputs t.op
    |> List.map ~f:(fun compiled -> Typed_op.Generated_file.Compiled compiled)
    |> Name.Set.of_list
  ;;

  let show_name name = Alice_ui.path_to_string (Name.path name)
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

let compilation_ops dir package_id build_dir =
  let ocamldep_cache = Ocamldep_cache.load build_dir package_id in
  let deps =
    Dir.contents dir
    |> List.filter ~f:(fun file ->
      File.is_regular_or_link file
      && (Path.has_extension file.path ~ext:".ml"
          || Path.has_extension file.path ~ext:".mli"))
    |> List.sort ~cmp:File.compare_by_path
    |> List.map ~f:(fun (file : _ File.t) ->
      file.path, Ocamldep_cache.get_deps ocamldep_cache ~source_path:file.path)
    |> Path.Absolute.Map.of_list_exn
  in
  Ocamldep_cache.store ocamldep_cache deps;
  Path.Absolute.Map.to_list deps
  |> List.map ~f:(fun (source_path, (deps : Alice_ocamldep.Deps.t)) ->
    let open Typed_op in
    let open Alice_error in
    match File.Source.of_path_by_extension source_path with
    | Error (`Unknown_extension _) ->
      panic
        [ Pp.textf
            "Tried to treat %S as source path but it has an unrecognized extension."
            (Alice_ui.path_to_string source_path)
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
                  (Alice_ui.path_to_string source_path)
                  (Alice_ui.path_to_string dep)
              ]
          | Error (`Unknown_extension _) ->
            panic
              [ Pp.textf
                  "Running ocamldep on %S produced build input %S whose extension is \
                   unrecognized."
                  (Alice_ui.path_to_string source_path)
                  (Alice_ui.path_to_string dep)
              ])
      in
      let source_file = Path.chop_prefix source_path ~prefix:(Dir.path dir) in
      let direct_output =
        Path.replace_extension source_file ~ext:".cmx"
        |> File.Compiled.cmx_infer_role_from_name
      in
      let indirect_output =
        Path.replace_extension source_file ~ext:".o"
        |> File.Compiled.o_infer_role_from_name
      in
      let matching_mli_file = Path.replace_extension source_path ~ext:".mli" in
      let interface_output_if_no_matching_mli_is_present =
        if Dir.contains dir matching_mli_file
        then None
        else
          Some
            (Path.replace_extension source_file ~ext:".cmi"
             |> File.Compiled.cmi_infer_role_from_name)
      in
      `Compile_source
        { Compile_source.direct_input
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
                  (Alice_ui.path_to_string source_path)
                  (Alice_ui.path_to_string dep)
              ]
          | Error (`Unknown_extension _) ->
            panic
              [ Pp.textf
                  "Running ocamldep on %S produced build input %S whose extension is \
                   unrecognized."
                  (Alice_ui.path_to_string source_path)
                  (Alice_ui.path_to_string dep)
              ])
      in
      let direct_output =
        Path.chop_prefix source_path ~prefix:(Dir.path dir)
        |> Path.replace_extension ~ext:".cmi"
        |> File.Compiled.cmi_infer_role_from_name
      in
      `Compile_interface
        { Compile_interface.direct_input; indirect_inputs; direct_output })
;;

let cmx_files_of_compilation_ops =
  List.filter_map ~f:(function
    | `Compile_source { Typed_op.Compile_source.direct_output; _ } -> Some direct_output
    | _ -> None)
;;

type ('exe, 'lib) t =
  { build_dag : Build_dag.t
  ; exe_file : Typed_op.File_type.exe Typed_op.File.Linked.t
  }

let to_dyn { build_dag; exe_file } =
  Dyn.record
    [ "build_dag", Build_dag.to_dyn build_dag
    ; "exe_file", Typed_op.File.Linked.to_dyn exe_file
    ]
;;

let create : type exe lib. (exe, lib) Package.Typed.t -> Build_dir.t -> (exe, lib) t =
  fun package_typed build_dir ->
  let open Typed_op in
  let package = Package.Typed.package package_typed in
  let src_dir = Package.src_dir_exn package in
  let compilation_ops = compilation_ops src_dir (Package.id package) build_dir in
  let cmx_files = cmx_files_of_compilation_ops compilation_ops in
  let link_library () = Link_library (Link_library.of_inputs cmx_files) in
  let exe_file =
    let exe_name =
      let base = Path.relative (Package.name package |> Package_name.to_string) in
      if Sys.win32 then Path.add_extension base ~ext:".exe" else base
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
  let ops =
    link_ops
    @ List.map compilation_ops ~f:(function
      | `Compile_source x -> Compile_source x
      | `Compile_interface x -> Compile_interface x)
  in
  let build_dag = Build_dag.of_ops ops in
  { build_dag; exe_file }
;;

let plan_exe ({ build_dag; exe_file } : (Type_bool.true_t, _) t) =
  Build_dag.traverse build_dag ~output:(Typed_op.File.Linked.generated_file exe_file)
  |> Option.get
;;

let plan_lib ({ build_dag; _ } : (_, Type_bool.true_t) t) =
  Build_dag.traverse build_dag ~output:(Typed_op.Generated_file.Linked_library Cmxa)
  |> Option.get
;;

let create_exe_plan package_typed build_dir = create package_typed build_dir |> plan_exe
let create_lib_plan package_typed build_dir = create package_typed build_dir |> plan_lib
let dot t = ""
