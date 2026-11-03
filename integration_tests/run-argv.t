Test that programs run with `alice run` see the expected arguments via argv.

  $ alice new --normalize-paths --hide-time --exe echo
   Creating new executable package "echo" in echo

  $ cd echo

  $ cat > src/main.ml <<EOF
  > let () =
  >   let args = Array.to_list Sys.argv |> List.tl in
  >   print_endline (String.concat " " args)
  > EOF

  $ alice run --normalize-paths --hide-time -- foo bar baz
   Building echo v0.1.0 (native, debug)
      Built echo v0.1.0 (native, debug)
    Running echo v0.1.0
  
  foo bar baz

  $ alice run --normalize-paths --hide-time -b bytecode -- foo bar baz
   Building echo v0.1.0 (bytecode, debug)
      Built echo v0.1.0 (bytecode, debug)
    Running echo v0.1.0
  
  foo bar baz
