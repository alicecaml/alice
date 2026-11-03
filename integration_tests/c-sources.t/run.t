Test that Alice can build projects with a mix of OCaml and C source code.

  $ alice run --normalize-paths --hide-time -m ./exe_with_c_sources/Alice.kdl
   Building exe_with_c_source v0.1.0 (native, debug)
      Built exe_with_c_source v0.1.0 (native, debug)
    Running exe_with_c_source v0.1.0
  
  Hello, World!

  $ alice build -m ./lib_with_c_sources/Alice.kdl
   Building lib_with_c_sources v0.1.0 (native, debug)
      Built lib_with_c_sources v0.1.0 (native, debug) in 0.23s

  $ alice run --normalize-paths --hide-time -m ./depend_on_lib_with_c_sources/Alice.kdl
   Building lib_with_c_sources v0.1.0 (native, debug)
   Building depend_on_lib_with_c_sources v0.1.0 (native, debug)
      Built depend_on_lib_with_c_sources v0.1.0 (native, debug)
    Running depend_on_lib_with_c_sources v0.1.0
  
  Hello, World!

Repeat the test with the bytecode compiler:

  $ alice run --normalize-paths --hide-time -m ./exe_with_c_sources/Alice.kdl -b bytecode
   Building exe_with_c_source v0.1.0 (bytecode, debug)
      Built exe_with_c_source v0.1.0 (bytecode, debug)
    Running exe_with_c_source v0.1.0
  
  Hello, World!

  $ alice build -m ./lib_with_c_sources/Alice.kdl -b bytecode
   Building lib_with_c_sources v0.1.0 (bytecode, debug)
      Built lib_with_c_sources v0.1.0 (bytecode, debug) in 0.08s

  $ alice run --normalize-paths --hide-time -m ./depend_on_lib_with_c_sources/Alice.kdl -b bytecode
   Building lib_with_c_sources v0.1.0 (bytecode, debug)
   Building depend_on_lib_with_c_sources v0.1.0 (bytecode, debug)
      Built depend_on_lib_with_c_sources v0.1.0 (bytecode, debug)
    Running depend_on_lib_with_c_sources v0.1.0
  
  Hello, World!
