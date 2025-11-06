Build a package with dependencies.

  $ sanitize() {
  > cat | sed -E '/Command failed: /d' | sed -E '/File .*, line [0-9]+, characters/d' | sed -E 's/Unbound module "([^ ]*)"/Unbound module \1/'
  > }

  $ alice run --normalize-paths --manifest-path app/Alice.toml
   Compiling c v0.1.0
   Compiling b v0.1.0
   Compiling a v0.1.0
   Compiling d v0.1.0
   Compiling app v0.1.0
     Running app/build/packages/app-0.1.0/debug/executable/app
  
  Hello, World!
  Hello, World!
  Hello, World!
  blah blah blah
  foo bar baz
  Hello, World! blah blah blah

  $ alice dot packages --normalize-paths --manifest-path app/Alice.toml
  digraph {
    "a v0.1.0" -> {"b v0.1.0"}
    "app v0.1.0" -> {"a v0.1.0", "d v0.1.0"}
    "b v0.1.0" -> {"c v0.1.0"}
    "d v0.1.0" -> {"b v0.1.0", "c v0.1.0"}
  }

Make a new package to test some things which are not allowed:
  $ alice new --normalize-paths --exe bad
    Creating new executable package "bad" in bad
  $ cat >> bad/Alice.toml << EOF
  > [dependencies]
  > a = { path = "../a" }
  > EOF
  $ alice build --normalize-paths --manifest-path bad/Alice.toml
   Compiling c v0.1.0
   Compiling b v0.1.0
   Compiling a v0.1.0
   Compiling bad v0.1.0
    Finished debug build of package: 'bad v0.1.0'

Even though the package "c" is in the transitive dependency closure of "bad",
"bad" cannot refer directly to "c".
  $ cat > bad/src/main.ml << EOF
  > let () = print_endline C.Message.message
  > EOF
  $ alice build --normalize-paths --manifest-path bad/Alice.toml 2>&1  | sanitize
   Compiling bad v0.1.0
  1 | let () = print_endline C.Message.message
                             ^^^^^^^^^^^^^^^^^
  Error: Unbound module C
  

The package protocol creates a module "internal_modules_of_<package>" which is
publically visible to client code, however the module is shadowed with an empty
module and generates a warning. Check that this works as expected by attempting
to access the transitive dependency "c" from "bad" via this module.
  $ cat > bad/src/main.ml << EOF
  > let () = print_endline Internal_modules_of_c.Lib.Message.message
  > EOF
  $ alice build --normalize-paths --manifest-path bad/Alice.toml 2>&1  | sanitize
   Compiling bad v0.1.0
  1 | let () = print_endline Internal_modules_of_c.Lib.Message.message
                             ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Alert deprecated: module Public_interface_to_open_of_a.Internal_modules_of_c
  This module is an empty shadow of another module intended for internal use only.
  
  1 | let () = print_endline Internal_modules_of_c.Lib.Message.message
                             ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Error: Unbound module Internal_modules_of_c.Lib
  

The package protocol also creates a module
"public_interface_to_open_of_<package>". This module should be inaccessible to
client code, even when the package is an immediate dependency.

  $ cat > bad/src/main.ml << EOF
  > let () = print_endline Public_interface_to_open_of_a.A.C.Message.message
  > EOF
  $ alice build --normalize-paths --manifest-path bad/Alice.toml 2>&1  | sanitize
   Compiling bad v0.1.0
  1 | let () = print_endline Public_interface_to_open_of_a.A.C.Message.message
                             ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Alert deprecated: module Public_interface_to_open_of_a.Public_interface_to_open_of_a
  This module is an empty shadow of another module intended for internal use only.
  
  1 | let () = print_endline Public_interface_to_open_of_a.A.C.Message.message
                             ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Error: Unbound module Public_interface_to_open_of_a.A
  

