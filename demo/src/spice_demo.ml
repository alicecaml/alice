module Dir = Spice_io.Hierarchy.Dir
module C_policy = Spice_policy.C

let () =
  let dir_path = Sys.argv.(1) in
  let dir = Dir.read ~dir_path in
  let ctx = C_policy.Ctx.debug in
  let exe_name = "foo" in
  let rules = C_policy.exe_rules ~exe_name ctx dir in
  ()
;;
