open! Alice_stdlib
open Alice_hierarchy
module C_policy = Alice_policy.C
module Ocaml_policy = Alice_policy.Ocaml

let run src_dir =
  let dir =
    match Alice_io.Read_hierarchy.read src_dir with
    | Error `Not_found ->
      Alice_error.panic [ Pp.textf "Dir not found: %s" (Path.to_filename src_dir) ]
    | Ok file -> File.as_dir file |> Option.get
  in
  let ctx = Ocaml_policy.Ctx.debug in
  let output = Path.relative "hello" in
  let traverse =
    Ocaml_policy.build_exe
      ctx
      ~exe_name:output
      ~root_ml:(Path.relative "hello.ml")
      ~src_dir:dir
  in
  Alice_io.File_ops.write_text_file
    (Path.absolute "/tmp/a.dot")
    (Alice_engine.Build_plan.Traverse.dot traverse);
  let out_dir = Path.relative "build" in
  let () = Alice_scheduler.Naive.run ~src_dir ~out_dir traverse in
  let _ =
    Alice_io.Process.Blocking.run
      (Path.concat out_dir output |> Path.to_filename)
      ~args:[]
  in
  ()
;;

let () =
  let dir = Sys.argv.(1) in
  Path.with_filename dir ~f:{ Path.f = run }
;;
