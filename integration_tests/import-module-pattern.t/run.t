Test that alice can handle the pattern of having an Import module with no mli
file which is opened in all other files (mli or ml).

  $ alice build
   Building import_module_pattern v0.1.0 (native, debug)
      Built import_module_pattern v0.1.0 (native, debug) in 0.51s

  $ alice build -b bytecode
   Building import_module_pattern v0.1.0 (bytecode, debug)
      Built import_module_pattern v0.1.0 (bytecode, debug) in 0.09s
