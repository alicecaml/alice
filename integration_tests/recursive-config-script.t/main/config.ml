let () =
  print_endline "alice:print_line:First line";
  print_endline (Config_script_helper.print_line "Second line");
  print_endline
    (Printf.sprintf "alice:print_line:Third line: %s %s" Some_lib.foo Lib_with_script.bar);
  ()
;;
