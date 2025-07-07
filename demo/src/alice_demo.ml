open! Alice_stdlib
open Alice_hierarchy
module C_policy = Alice_policy.C

let () =
  let dir = Sys.argv.(1) in
  Path.with_filename
    dir
    ~f:
      { Path.f =
          (fun dir ->
            let dir =
              match Alice_io.Read_hierarchy.read dir with
              | Error `Not_found ->
                Alice_error.panic [ Pp.textf "Dir not found: %s" (Path.to_filename dir) ]
              | Ok file -> File.as_dir file |> Option.get
            in
            let ctx = C_policy.Ctx.debug in
            let output = "a.out" in
            let rule_db = Alice_policy.C.exe_rules ~exe_name:output ctx dir in
            let build_plan =
              Alice_engine.Rule.Database.create_build_plan rule_db ~output
            in
            print_endline (Dir.to_dyn dir |> Dyn.to_string);
            print_endline (Alice_engine.Build_plan.to_dyn build_plan |> Dyn.to_string);
            let traverse =
              Alice_engine.Build_plan.traverse build_plan ~output |> Option.get
            in
            let () = Alice_scheduler.Naive.run traverse in
            print_endline (Filename.basename "/");
            ())
      }
;;
