Build a package with a config script, where that config script has a second
package containing a config script among its dependency closure.

  $ cd main
  $ alice run --normalize-paths --hide-time
   Building some_lib v0.1.0 (native, debug)
  Message from config script of package some_lib_with_config_script v0.1.0:
  >  Hello from some_lib_with_config_script's config script
  End of message (some_lib_with_config_script v0.1.0).
   Building some_lib_with_config_script v0.1.0 (native, debug)
   Building config_script_helper v0.1.0 (bytecode, debug)
   Building some_lib v0.1.0 (bytecode, debug)
  Message from config script of package some_lib_with_config_script v0.1.0:
  >  Hello from some_lib_with_config_script's config script
  End of message (some_lib_with_config_script v0.1.0).
   Building some_lib_with_config_script v0.1.0 (bytecode, debug)
  Message from config script of package main v0.1.0:
  >  First line
  >  Second line
  >  Third line: foo bar
  End of message (main v0.1.0).
   Building main v0.1.0 (native, debug)
      Built main v0.1.0 (native, debug)
    Running main v0.1.0
  
  foo
  bar
