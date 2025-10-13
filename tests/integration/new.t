Exercise initializing a new executable project.

  $ alice new hello --normalize-paths
    Creating new executable package "hello" in $TESTCASE_ROOT/hello
  
  $ cd hello

  $ alice run --normalize-paths
   Compiling hello v0.1.0
     Running $TESTCASE_ROOT/hello/build/packages/hello-0.1.0/hello
  
  Hello, World!
