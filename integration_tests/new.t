Exercise initializing a new executable project.

  $ alice new hello --normalize-paths
    Creating new executable package "hello" in hello
  $ cd hello

  $ alice run --normalize-paths
   Compiling hello v0.1.0
     Running build/packages/hello-0.1.0/debug/executable/hello
  
  Hello, World!

Test some error cases for `alice new`:
  $ alice new hello --path . --normalize-paths
    Creating new executable package "hello" in .
  
  Refusing to create project because destination directory exists and contains project manifest (Alice.kdl).
  Delete this file before proceeding.
  [1]

  $ rm Alice.kdl

  $ alice new hello --path . --normalize-paths
    Creating new executable package "hello" in .
  
  Refusing to create project because destination directory exists and contains src directory (src).
  Delete this directory before proceeding.
  [1]

  $ rm -r src
  $ touch src

  $ alice new hello --path . --normalize-paths
    Creating new executable package "hello" in .
  
  Refusing to create project because destination directory exists and contains a file named "src" (src).
  Delete this file before proceeding.
  [1]

  $ rm src

  $ alice new hello --path . --normalize-paths
    Creating new executable package "hello" in .
