open! Alice_stdlib
module Dir = Alice_io.Hierarchy.File.Dir
module C_policy = Alice_policy.C

let () =
  print_endline (sprintf "-m %s" (Alice_io.Uname.uname_m ()));
  print_endline (sprintf "-s %s" (Alice_io.Uname.uname_s ()))
;;
