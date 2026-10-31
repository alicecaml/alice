Test that alice packages can access the modules that are included in the OCaml
standard library outside stdlib (such as Unix and Str).

  $ cd main

  $ ls | sort
  Alice.kdl
  src

  $ alice run --normalize-paths
     Compiling requires_str v0.1.0 (native)
     Compiling requires_unix v0.1.0 (native)
     Compiling main v0.1.0 (native)
       Running build/packages/main-0.1.0/native/debug/executable/main
  

  $ ls | sort
  Alice.kdl
  build
  hello
  src

Repeat the test with the bytecode compiler:

  $ rm -rf build hello

  $ alice run --normalize-paths -b bytecode
     Compiling requires_str v0.1.0 (bytecode)
     Compiling requires_unix v0.1.0 (bytecode)
     Compiling main v0.1.0 (bytecode)
       Running build/packages/main-0.1.0/bytecode/debug/executable/main
  

  $ ls | sort
  Alice.kdl
  build
  hello
  src
