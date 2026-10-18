Test that Alice can build projects with a mix of OCaml and C source code.

  $ alice run -m ./exe_with_c_sources/Alice.kdl
   Compiling exe_with_c_source v0.1.0
     Running $TESTCASE_ROOT/exe_with_c_sources/build/packages/exe_with_c_source-0.1.0/debug/executable/exe_with_c_source
  
  Hello, World!

  $ alice build -m ./lib_with_c_sources/Alice.kdl
   Compiling lib_with_c_sources v0.1.0
    Finished debug build of package: 'lib_with_c_sources v0.1.0'

  $ alice run -m ./depend_on_lib_with_c_sources/Alice.kdl
   Compiling lib_with_c_sources v0.1.0
   Compiling depend_on_lib_with_c_sources v0.1.0
     Running $TESTCASE_ROOT/depend_on_lib_with_c_sources/build/packages/depend_on_lib_with_c_sources-0.1.0/debug/executable/depend_on_lib_with_c_sources
  
  Hello, World!
