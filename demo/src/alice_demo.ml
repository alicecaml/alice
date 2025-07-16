open! Alice_stdlib
open Alice_hierarchy
module C_policy = Alice_policy.C

let run src_dir =
  let dir =
    match Alice_io.Read_hierarchy.read src_dir with
    | Error `Not_found ->
      Alice_error.panic [ Pp.textf "Dir not found: %s" (Path.to_filename src_dir) ]
    | Ok file -> File.as_dir file |> Option.get |> Dir.to_relative
  in
  let ctx = C_policy.Ctx.debug in
  let output = Path.relative "a.out" in
  let rule_db = Alice_policy.C.exe_rules ~exe_name:output ctx dir in
  let build_plan = Alice_engine.Rule.Database.create_build_plan rule_db ~output in
  Alice_io.File_ops.write_text_file
    (Path.absolute "/tmp/a.dot")
    (Alice_engine.Build_plan.dot build_plan);
  let traverse = Alice_engine.Build_plan.traverse build_plan ~output |> Option.get in
  let out_dir = Path.absolute "/tmp/build" in
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
