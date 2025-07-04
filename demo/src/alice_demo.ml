open! Alice_stdlib
module File = Alice_io.Hierarchy.File
module Dir = Alice_io.Hierarchy.Dir
module C_policy = Alice_policy.C

let () =
  let dir = Sys.argv.(1) in
  let dir = File.read dir |> Result.get_ok |> File.as_dir |> Option.get in
  let ctx = C_policy.Ctx.debug in
  let rule_db = Alice_policy.C.exe_rules ~exe_name:"a.out" ctx dir in
  let build_plan = Alice_engine.Rule.Database.create_build_plan rule_db ~output:"a.out" in
  print_endline (Dir.to_dyn dir |> Dyn.to_string);
  print_endline (Alice_engine.Build_plan.to_dyn build_plan |> Dyn.to_string);
  ()
;;
