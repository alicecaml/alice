let () =
  (* Exercise linker scripts' ability to depend on other packages including
     packages containing C code. Adds a benign linker arg "-lm". *)
  print_endline Hello.Foo.message;
  Lib_with_c_sources.go ();
  Array.iteri (fun i arg -> print_endline (Printf.sprintf "arg %d: %s" i arg)) Sys.argv;
  print_endline "alice:print_line:Hello, World!";
  print_endline "alice:add_c_linker_args:-lm";
  print_endline "alice:print_line: ...a second message";
  match Sys.getenv_opt "FOO" with
  | None -> print_endline "env var \"FOO\" is unset"
  | Some value -> print_endline (Printf.sprintf "FOO = %S" value)
;;
