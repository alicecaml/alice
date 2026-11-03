Test that packages can have a lib.mli file.

  $ alice run --normalize-paths --hide-time --manifest-path client/Alice.kdl
   Building lib_with_interface v0.1.0 (native, debug)
   Building client v0.1.0 (native, debug)
      Built client v0.1.0 (native, debug)
    Running client v0.1.0
  
  Hello, 42!
