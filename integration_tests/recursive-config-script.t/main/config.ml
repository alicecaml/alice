let () =
  print_endline "alice:print_line:First line";
  print_endline (Config_script_helper.print_line "Second line");
  print_endline
    (Printf.sprintf
       "alice:print_line:Third line: %s %s"
       Some_lib.foo
       Some_lib_with_config_script.bar);
  ()
;;
