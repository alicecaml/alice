let () =
  print_endline A.C.Message.message;
  print_endline A.C_again.Message.message;
  print_endline A.B_plus.Another_alias_of_c.Message.message;
  print_endline A.B_plus.another_message;
  print_endline A.B_plus.yet_another_message;
  print_endline D.Foo_exported.message
;;
