Build a package with a config script, where that config script has a second
package containing a config script among its dependency closure.

  $ cd main
  $ alice run --normalize-paths
     Compiling some_lib v0.1.0 (native)
   Configuring some_lib_with_config_script v0.1.0
  Message from config script of package some_lib_with_config_script v0.1.0:
  >  Hello from some_lib_with_config_script's config script
  End of message (some_lib_with_config_script v0.1.0).
     Compiling some_lib_with_config_script v0.1.0 (native)
     Compiling config_script_helper v0.1.0 (bytecode)
     Compiling some_lib v0.1.0 (bytecode)
   Configuring some_lib_with_config_script v0.1.0
  Message from config script of package some_lib_with_config_script v0.1.0:
  >  Hello from some_lib_with_config_script's config script
  End of message (some_lib_with_config_script v0.1.0).
     Compiling some_lib_with_config_script v0.1.0 (bytecode)
   Configuring main v0.1.0
  Message from config script of package main v0.1.0:
  >  First line
  >  Second line
  >  Third line: foo bar
  End of message (main v0.1.0).
     Compiling main v0.1.0 (native)
       Running build/packages/main-0.1.0/native/debug/executable/main
  
  foo
  bar
