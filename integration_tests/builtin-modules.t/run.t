Test that alice packages can access the modules that are included in the OCaml
standard library outside stdlib (such as Unix and Str).

  $ cd main

  $ ls | sort
  Alice.kdl
  src

  $ alice run --normalize-paths --hide-time
   Building requires_str v0.1.0 (native, debug)
   Building requires_unix v0.1.0 (native, debug)
   Building main v0.1.0 (native, debug)
      Built main v0.1.0 (native, debug)
    Running main v0.1.0
  

  $ ls | sort
  Alice.kdl
  build
  hello
  src

Repeat the test with the bytecode compiler:

  $ rm -rf build hello

  $ alice run --normalize-paths --hide-time -b bytecode
   Building requires_str v0.1.0 (bytecode, debug)
   Building requires_unix v0.1.0 (bytecode, debug)
   Building main v0.1.0 (bytecode, debug)
      Built main v0.1.0 (bytecode, debug)
    Running main v0.1.0
  

  $ ls | sort
  Alice.kdl
  build
  hello
  src
