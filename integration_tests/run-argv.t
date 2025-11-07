Test that programs run with `alice run` see the expected arguments via argv.

  $ alice new --normalize-paths --exe echo
    Creating new executable package "echo" in echo

  $ cd echo

  $ cat > src/main.ml <<EOF
  > let () =
  >   let args = Array.to_list Sys.argv |> List.tl in
  >   print_endline (String.concat " " args)
  > EOF

  $ alice run --normalize-paths -- foo bar baz
   Compiling echo v0.1.0
     Running build/packages/echo-0.1.0/debug/executable/echo
  
  foo bar baz
