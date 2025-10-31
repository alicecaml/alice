open! Alice_stdlib
open Alice_hierarchy
open Alice_package

module Build_node = struct
  module Name = Path.Relative

  type t =
    { artifact : Path.Relative.t
    ; op : Typed_op.t
    }

  let to_dyn { artifact; op } =
    Dyn.record [ "artifact", Path.Relative.to_dyn artifact; "op", Typed_op.to_dyn op ]
  ;;

  let equal t { artifact; op } =
    Path.Relative.equal t.artifact artifact && Typed_op.equal t.op op
  ;;

  let name t = t.artifact
  let dep_names t = Name.Set.of_list @@ Typed_op.generated_inputs t.op
  let show t = Alice_ui.path_to_string t.artifact
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
            [ Pp.textf
                "Conflicting origins for file: %s"
                (Alice_ui.path_to_string artifact)
            ])
    ;;

    let finalize t =
      match finalize t with
      | Ok t -> t
      | Error (`Dangling dangling) ->
        Alice_error.panic
          [ Pp.textf "No rule to build: %s" (Alice_ui.path_to_string dangling) ]
      | Error (`Cycle cycle) ->
        Alice_error.panic
          ([ Pp.text "Dependency cycle:"; Pp.newline ]
           @ List.concat_map cycle ~f:(fun file ->
             [ Pp.textf " - %s" (Alice_ui.path_to_string file); Pp.newline ]))
    ;;
  end

  let of_ops ops =
    List.fold_left ops ~init:Staging.empty ~f:Staging.add_op |> Staging.finalize
  ;;

  let traverse t ~output = traverse t ~name:output
end

module Artifact_with_origin = struct
  module Name = Path.Absolute

  (** A build artifact along with its origin. *)
  type t =
    { artifact : Path.Absolute.t
    ; origin : Origin.t
    }

  let to_dyn { origin; artifact } =
    Dyn.record
      [ "artifact", Path.Absolute.to_dyn artifact; "origin", Origin.to_dyn origin ]
  ;;

  let equal t { artifact; origin } =
    Path.Absolute.equal t.artifact artifact && Origin.equal t.origin origin
  ;;

  let name t = t.artifact
  let dep_names t = Origin.inputs t.origin
  let show t = Alice_ui.path_to_string t.artifact
end

include Alice_dag.Make (Artifact_with_origin)

module Traverse = struct
  include Traverse

  let origin t = (node t).origin
  let outputs t = Origin.outputs (origin t)
end

let traverse t ~output = traverse t ~name:output

module Staging = struct
  include Staging

  let add_origin t origin =
    Path.Absolute.Set.fold (Origin.outputs origin) ~init:t ~f:(fun output t ->
      let artifact_with_origin = { Artifact_with_origin.artifact = output; origin } in
      match add t output artifact_with_origin with
      | Ok t -> t
      | Error (`Conflict _) ->
        Alice_error.panic
          [ Pp.textf "Conflicting origins for file: %s" (Alice_ui.path_to_string output) ])
  ;;

  let finalize t =
    match finalize t with
    | Ok t -> t
    | Error (`Dangling dangling) ->
      Alice_error.panic
        [ Pp.textf "No rule to build: %s" (Alice_ui.path_to_string dangling) ]
    | Error (`Cycle cycle) ->
      Alice_error.panic
        ([ Pp.text "Dependency cycle:"; Pp.newline ]
         @ List.concat_map cycle ~f:(fun file ->
           [ Pp.textf " - %s" (Alice_ui.path_to_string file); Pp.newline ]))
  ;;
end

let dot t = to_string_graph t |> Alice_graphviz.dot_src_of_string_graph

let create builds ~outputs =
  let find_for_output_file_opt ~output =
    List.find_opt builds ~f:(fun (build : Origin.Build.t) ->
      Path.Absolute.Set.mem output build.outputs)
  in
  let rec loop output acc =
    let origin =
      match find_for_output_file_opt ~output with
      | None -> Origin.Source output
      | Some build -> Origin.Build build
    in
    let acc = Staging.add_origin acc origin in
    Origin.inputs origin |> Path.Absolute.Set.fold ~init:acc ~f:loop
  in
  let staged =
    List.fold_left outputs ~init:Staging.empty ~f:(fun acc output -> loop output acc)
  in
  Staging.finalize staged
;;

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

module X = struct
  type ('exe, 'lib) t =
    { build_dag : Build_dag.t
    ; exe_file : Typed_op.File_type.exe Typed_op.File.Linked.t
    }

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
    Build_dag.traverse build_dag ~output:(Typed_op.File.Linked.path exe_file)
    |> Option.get
  ;;

  let plan_lib ({ build_dag; _ } : (_, Type_bool.true_t) t) =
    Build_dag.traverse
      build_dag
      ~output:(Typed_op.File.Linked.path Typed_op.File.Linked.lib_cmxa)
    |> Option.get
  ;;
end

let plan_exe package_typed build_dir = X.create package_typed build_dir |> X.plan_exe
let plan_lib package_typed build_dir = X.create package_typed build_dir |> X.plan_lib
