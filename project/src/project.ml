open! Alice_stdlib
open Alice_hierarchy
open Alice_error
module File_ops = Alice_io.File_ops

let manifest_name = "Alice.toml"

type t =
  { root : Path.Absolute.t
  ; manifest : Alice_manifest.Project.t
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
  let out = Path.relative "build"

  (* The file inside the source directory containing the entry point for the
     executable, if the project contains an executable. *)
  let exe_root_ml = Path.relative "main.ml"

  (* The file inside the source directory containing the entry point for the
     library, if the project contains a library. *)
  let lib_root_ml = Path.relative "lib.ml"
end

let src_dir t = Path.concat t.root Paths.src
let out_dir t = Path.concat t.root Paths.out
let contains_exe t = File_ops.exists (Path.concat (src_dir t) Paths.exe_root_ml)
let contains_lib t = File_ops.exists (Path.concat (src_dir t) Paths.lib_root_ml)

let package_name t =
  Alice_manifest.Package_name.to_string t.manifest.package.name |> Path.relative
;;

let read_src_dir t =
  let src_dir = src_dir t in
  match Alice_io.Read_hierarchy.read src_dir with
  | Error `Not_found ->
    user_error [ Pp.textf "Directory not found: %s" (Path.to_filename src_dir) ]
  | Ok file ->
    (match File.as_dir file with
     | Some dir -> dir
     | None -> user_error [ Pp.textf "%S is not a directory" (Path.to_filename src_dir) ])
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
  let src_dir = read_src_dir t in
  Alice_policy.Ocaml.Plan.create
    ctx
    ~name:(package_name t)
    ~exe_root_ml
    ~lib_root_ml
    ~src_dir
;;

let run_traverse t ~traverse =
  Alice_scheduler.Sequential.run ~src_dir:(src_dir t) ~out_dir:(out_dir t) traverse
;;

let build_ocaml ~ctx t =
  let ocaml_plan = ocaml_plan ~ctx ~exe_only:false t in
  if contains_lib t
  then run_traverse t ~traverse:(Alice_policy.Ocaml.Plan.traverse_lib ocaml_plan);
  if contains_exe t
  then run_traverse t ~traverse:(Alice_policy.Ocaml.Plan.traverse_exe ocaml_plan)
;;

let run_ocaml_exe ~ctx t ~args =
  (match contains_exe t with
   | true -> ()
   | false -> panic [ Pp.text "Cannot run project as it lacks an executable." ]);
  let ocaml_plan = ocaml_plan ~ctx ~exe_only:true t in
  run_traverse t ~traverse:(Alice_policy.Ocaml.Plan.traverse_exe ocaml_plan);
  let exe_name = package_name t in
  let exe_path = Path.concat (out_dir t) exe_name in
  let args = Path.to_filename exe_name :: args in
  Unix.execv (Path.to_filename exe_path) (Array.of_list args)
;;

let clean t = File_ops.rm_rf (out_dir t)

let dot_ocaml ~ctx t =
  let ocaml_plan = ocaml_plan ~ctx ~exe_only:false t in
  let build_plan = Alice_policy.Ocaml.Plan.build_plan ocaml_plan in
  Alice_engine.Build_plan.dot build_plan
;;

let new_ocaml name path kind =
  if File_ops.exists path
  then
    user_error
      [ Pp.text
          "Refusing to create project because destination directory already exists.\n"
      ; Pp.textf "Destination directory is: %s" (Path.to_filename path)
      ];
  let manifest =
    { Alice_manifest.Project.package =
        { name; version = Alice_manifest.Semantic_version.of_string "0.1.0" }
    }
  in
  File_ops.mkdir_p (Path.concat path Paths.src);
  File_ops.write_text_file
    (Path.concat path (Path.relative ".gitignore"))
    (Path.to_filename Paths.out);
  File_ops.write_text_file
    (Path.concat path (Path.relative manifest_name))
    (Alice_manifest.Project.to_toml_string manifest);
  match kind with
  | `Exe ->
    File_ops.write_text_file
      (Path.concat (Path.concat path Paths.src) Paths.exe_root_ml)
      "let () = print_endline \"Hello, World!\""
  | `Lib ->
    File_ops.write_text_file
      (Path.concat (Path.concat path Paths.src) Paths.lib_root_ml)
      "let add lhs rhs = lhs + rhs"
;;
