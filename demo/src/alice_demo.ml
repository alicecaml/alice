module Dir = Alice_io.Hierarchy.Dir
module C_policy = Alice_policy.C

let () =
  let path = Alice_io.Temp_dir.mkdir ~prefix:"alice." ~suffix:".foo" in
  print_endline path
;;
