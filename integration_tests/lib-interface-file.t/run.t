Test that packages can have a lib.mli file.

  $ alice run --normalize-paths --manifest-path client/Alice.kdl
   Compiling lib_with_interface v0.1.0
   Compiling client v0.1.0
     Running client/build/packages/client-0.1.0/debug/executable/client
  
  Hello, 42!
