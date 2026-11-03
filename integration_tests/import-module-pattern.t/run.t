Test that alice can handle the pattern of having an Import module with no mli
file which is opened in all other files (mli or ml).

  $ alice build --hide-time
   Building import_module_pattern v0.1.0 (native, debug)
      Built import_module_pattern v0.1.0 (native, debug)

  $ alice build -b bytecode --hide-time
   Building import_module_pattern v0.1.0 (bytecode, debug)
      Built import_module_pattern v0.1.0 (bytecode, debug)
