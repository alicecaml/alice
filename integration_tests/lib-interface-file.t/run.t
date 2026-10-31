Test that packages can have a lib.mli file.

  $ alice run --normalize-paths --manifest-path client/Alice.kdl
     Compiling lib_with_interface v0.1.0 (native)
     Compiling client v0.1.0 (native)
       Running client/build/packages/client-0.1.0/native/debug/executable/client
  
  Hello, 42!
