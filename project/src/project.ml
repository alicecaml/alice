open! Alice_stdlib
open Alice_hierarchy
open Alice_error
open Alice_package
module File_ops = Alice_io.File_ops

type t =
  { root : Path.Absolute.t
  ; manifest : Alice_package.Package.t
  }

let create ~root ~manifest = { root; manifest }

(* Paths relating to the layout of a project. In the future it might make
   sense to make these fields of the project type rather than hard-coded them
   here. *)
module Paths = struct
  (* The directory inside a project where the source code is located. *)
  let src = Path.relative "src"

  (* The directory that will be created at the top level of the project
     directory to contain all intermediate and final build artifacts. *)
  let build = Path.relative "build"

  (* The file inside the source directory containing the entry point for the
     executable, if the project contains an executable. *)
  let exe_root_ml = Path.relative "main.ml"

  (* The file inside the source directory containing the entry point for the
     library, if the project contains a library. *)
  let lib_root_ml = Path.relative "lib.ml"
  let manifest = Path.relative Alice_manifest.manifest_name
end

let src_dir t = t.root / Paths.src
let build_dir t = t.root / Paths.build

let out_dir t =
  Path.concat_multi
    (build_dir t)
    [ Path.relative "packages"
    ; Path.relative (Package.id t.manifest |> Package_id.name_dash_version_string)
    ]
;;

let contains_exe t = File_ops.exists (src_dir t / Paths.exe_root_ml)
let contains_lib t = File_ops.exists (src_dir t / Paths.lib_root_ml)
let package_name t = Package_name.to_string (Package.id t.manifest).name

let read_dir path =
  match Alice_io.Read_hierarchy.read path with
  | Error `Not_found ->
    Error [ Pp.textf "Directory not found: %s" (Alice_ui.path_to_string path) ]
  | Ok file ->
    (match File.as_dir file with
     | Some dir -> Ok dir
     | None -> Error [ Pp.textf "%S is not a directory" (Alice_ui.path_to_string path) ])
;;

let read_dir_exn path =
  match read_dir path with
  | Ok x -> x
  | Error pps -> user_exn pps
;;

let ocaml_plan ~ctx ~exe_only t =
  let exe_root_ml =
    match contains_exe t with
    | true -> Some Paths.exe_root_ml
    | false -> None
  in
  let lib_root_ml =
    match (not exe_only) && contains_lib t with
    | true -> Some Paths.lib_root_ml
    | false -> None
  in
  let src_dir = read_dir_exn (src_dir t) in
  let out_dir = out_dir t in
  Alice_policy.Ocaml.Plan.create
    ctx
    ~name:(package_name t |> Path.relative)
    ~exe_root_ml
    ~lib_root_ml
    ~src_dir
    ~out_dir
    ~package:(Package.id t.manifest)
;;

let run_traverse t ~traverse =
  Alice_scheduler.Sequential.run
    ~src_dir:(src_dir t)
    ~out_dir:(out_dir t)
    ~package:(Package.id t.manifest)
    traverse
;;

let compiling_message t =
  let open Alice_ui in
  let package = Package.id t.manifest in
  let name_string = Package_name.to_string package.name in
  let version_string = Semantic_version.to_string package.version in
  verb_message `Compiling (sprintf "%s v%s" name_string version_string)
;;

let build_ocaml ~ctx t =
  let open Alice_ui in
  println (compiling_message t);
  let ocaml_plan = ocaml_plan ~ctx ~exe_only:false t in
  if contains_lib t
  then run_traverse t ~traverse:(Alice_policy.Ocaml.Plan.traverse_lib ocaml_plan);
  if contains_exe t
  then run_traverse t ~traverse:(Alice_policy.Ocaml.Plan.traverse_exe ocaml_plan)
;;

let run_ocaml_exe ~ctx t ~args =
  let open Alice_ui in
  (match contains_exe t with
   | true -> ()
   | false -> panic [ Pp.text "Cannot run project as it lacks an executable." ]);
  let ocaml_plan = ocaml_plan ~ctx ~exe_only:true t in
  println (compiling_message t);
  let traverse = Alice_policy.Ocaml.Plan.traverse_exe ocaml_plan in
  run_traverse t ~traverse;
  let exe_name =
    match
      Path.Relative.Set.to_list (Alice_engine.Build_plan.Traverse.outputs traverse)
    with
    | [ exe_name ] -> exe_name
    | _ ->
      (* This should never happen but let's try to handle it anyway. *)
      let exe_name = package_name t |> Path.relative in
      if Sys.win32 then Path.add_extension exe_name ~ext:".exe" else exe_name
  in
  let exe_path = out_dir t / exe_name in
  let args = Path.to_filename exe_name :: args in
  let exe_filename = Path.to_filename exe_path in
  println (verb_message `Running (path_to_string exe_path));
  print_newline ();
  match Alice_io.Process.Blocking.run exe_filename ~args with
  | Error `Prog_not_available ->
    panic
      [ Pp.textf
          "The executable %s does not exist. Alice was supposed to create that file. \
           This is a bug in Alice."
          exe_filename
      ]
  | Ok (Exited code) -> exit code
  | Ok (Signaled signal | Stopped signal) ->
    println
      (raw_message
         (sprintf "The executable %s was stopped by a signal (%d)." exe_filename signal));
    exit 0
;;

let clean t =
  let open Alice_ui in
  println (verb_message `Removing (Alice_ui.path_to_string (build_dir t)));
  File_ops.rm_rf (build_dir t)
;;

let dot_build_artifacts t =
  let ocaml_plan = ocaml_plan ~ctx:Alice_policy.Ocaml.Ctx.debug ~exe_only:false t in
  let build_plan = Alice_policy.Ocaml.Plan.build_plan ocaml_plan in
  Alice_engine.Build_plan.dot build_plan
;;

let dot_package_dependencies t =
  let dependency_graph = Alice_dependencies.resolve t.manifest in
  Alice_engine.Dependency_graph.dot dependency_graph
;;

let new_ocaml name path kind =
  if File_ops.exists (path / Paths.manifest)
  then
    user_exn
      [ Pp.textf
          "Refusing to create project because destination directory exists and contains \
           project manifest (%s).\n"
          (Alice_ui.path_to_string (path / Paths.manifest))
      ; Pp.text "Delete this file before proceeding."
      ];
  if File_ops.exists (path / Paths.src)
  then
    if File_ops.is_directory (path / Paths.src)
    then
      user_exn
        [ Pp.textf
            "Refusing to create project because destination directory exists and \
             contains src directory (%s).\n"
            (Alice_ui.path_to_string (path / Paths.src))
        ; Pp.text "Delete this directory before proceeding."
        ]
    else
      user_exn
        [ Pp.textf
            "Refusing to create project because destination directory exists and \
             contains a file named \"src\" (%s).\n"
            (Alice_ui.path_to_string (path / Paths.src))
        ; Pp.text "Delete this file before proceeding."
        ];
  let manifest =
    Alice_package.Package.create
      ~id:
        { name
        ; version = Semantic_version.of_string_res "0.1.0" |> User_error.get_or_panic
        }
      ~dependencies:None
  in
  File_ops.mkdir_p (path / Paths.src);
  File_ops.write_text_file
    (path / Path.relative ".gitignore")
    (Path.to_filename Paths.build);
  Alice_manifest.write_package_manifest ~manifest_path:(path / Paths.manifest) manifest;
  match kind with
  | `Exe ->
    File_ops.write_text_file
      (path / Paths.src / Paths.exe_root_ml)
      "let () = print_endline \"Hello, World!\""
  | `Lib ->
    File_ops.write_text_file
      (path / Paths.src / Paths.lib_root_ml)
      "let add lhs rhs = lhs + rhs"
;;
