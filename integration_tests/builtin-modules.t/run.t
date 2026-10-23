Test that alice packages can access the modules that are included in the OCaml
standard library outside stdlib (such as Unix and Str).

  $ cd main
  $ alice run --normalize-paths
   Compiling requires_str v0.1.0
   Compiling requires_unix v0.1.0
   Compiling main v0.1.0
     Running build/packages/main-0.1.0/debug/executable/main
  

  $ ls | sort
  Alice.kdl
  build
  hello
  src
