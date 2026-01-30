Exercise building a multi-file project.

Create a multi-file project:
  $ mkdir src

  $ cat > src/foo_dep.ml <<EOF
  > let message = "Hello"
  > EOF

  $ cat > src/foo_dep.mli <<EOF
  > val message : string
  > EOF

  $ cat > src/foo.ml <<EOF
  > let hello = Foo_dep.message
  > EOF

  $ cat > src/foo.mli <<EOF
  > val hello : string
  > EOF

  $ cat > src/bar.ml <<EOF
  > let world = "World"
  > EOF

  $ cat > src/lib.ml <<EOF
  > module Foo = Foo
  > let text = Printf.sprintf "%s, %s!" Foo.hello Bar.world
  > EOF

  $ cat > src/main.ml <<EOF
  > let () = print_endline Lib.text
  > EOF

  $ cat > Alice.kdl <<EOF
  > package {
  >   name foo
  >   version "0.1.0"
  > }
  > EOF

Print the dependency graph of the project:
  $ alice dot artifacts --normalize-paths
  digraph {
    "bar.cmi" -> {"bar.ml"}
    "bar.cmt" -> {"bar.ml"}
    "bar.cmx" -> {"bar.ml"}
    "foo" -> {"bar.cmx", "foo.cmx", "foo_dep.cmx", "lib.cmx", "main.cmx"}
    "foo.cmi" -> {"foo.mli"}
    "foo.cmi (for lsp)" -> {"bar.cmx", "foo.cmx", "internal_modules_of_foo.cmx", "lib.ml"}
    "foo.cmt" -> {"foo.cmi", "foo.ml", "foo_dep.cmx"}
    "foo.cmt (for lsp)" -> {"bar.cmx", "foo.cmx", "internal_modules_of_foo.cmx", "lib.ml"}
    "foo.cmti" -> {"foo.mli"}
    "foo.cmx" -> {"foo.cmi", "foo.ml", "foo_dep.cmx"}
    "foo_dep.cmi" -> {"foo_dep.mli"}
    "foo_dep.cmt" -> {"foo_dep.cmi", "foo_dep.ml"}
    "foo_dep.cmti" -> {"foo_dep.mli"}
    "foo_dep.cmx" -> {"foo_dep.cmi", "foo_dep.ml"}
    "internal_modules_of_foo.cmx" -> {"bar.cmx", "foo.cmx", "foo_dep.cmx", "lib.cmx"}
    "lib.a" -> {"internal_modules_of_foo.cmx", "public_interface_to_open_of_foo.cmx"}
    "lib.cmi" -> {"bar.cmx", "foo.cmx", "lib.ml"}
    "lib.cmt" -> {"bar.cmx", "foo.cmx", "lib.ml"}
    "lib.cmx" -> {"bar.cmx", "foo.cmx", "lib.ml"}
    "lib.cmxa" -> {"internal_modules_of_foo.cmx", "public_interface_to_open_of_foo.cmx"}
    "main.cmi" -> {"lib.cmx", "main.ml"}
    "main.cmt" -> {"lib.cmx", "main.ml"}
    "main.cmx" -> {"lib.cmx", "main.ml"}
    "public_interface_to_open_of_foo.cmx" -> {"internal_modules_of_foo.cmx", "public_interface_to_open_of_foo.ml"}
  }

Test that the project can be built an run:
  $ alice run --normalize-paths
   Compiling foo v0.1.0
     Running build/packages/foo-0.1.0/debug/executable/foo
  
  Hello, World!

  $ alice clean --normalize-paths
    Removing build

Now test Alice's incremental recomputation by repeatedly changing files and
rebuilding the project.

Initial build:
  $ alice build --normalize-paths --verbose -j1
   [INFO] [foo v0.1.0] Analyzing dependencies of file: src/bar.ml
   [INFO] [foo v0.1.0] Analyzing dependencies of file: src/foo.ml
   [INFO] [foo v0.1.0] Analyzing dependencies of file: src/foo.mli
   [INFO] [foo v0.1.0] Analyzing dependencies of file: src/foo_dep.ml
   [INFO] [foo v0.1.0] Analyzing dependencies of file: src/foo_dep.mli
   [INFO] [foo v0.1.0] Analyzing dependencies of file: src/lib.ml
   [INFO] [foo v0.1.0] Analyzing dependencies of file: src/main.ml
   Compiling foo v0.1.0
   [INFO] [foo v0.1.0] Building targets: bar.cmi, bar.cmt, bar.cmx
   [INFO] [foo v0.1.0] Building targets: foo.cmi, foo.cmti
   [INFO] [foo v0.1.0] Building targets: foo_dep.cmi, foo_dep.cmti
   [INFO] [foo v0.1.0] Building targets: public_interface_to_open_of_foo.ml
   [INFO] [foo v0.1.0] Building targets: foo_dep.cmt, foo_dep.cmx
   [INFO] [foo v0.1.0] Building targets: foo.cmt, foo.cmx
   [INFO] [foo v0.1.0] Building targets: lib.cmi, lib.cmt, lib.cmx
   [INFO] [foo v0.1.0] Building targets: main.cmi, main.cmt, main.cmx
   [INFO] [foo v0.1.0] Building targets: internal_modules_of_foo.cmx
   [INFO] [foo v0.1.0] Building targets: foo
   [INFO] [foo v0.1.0] Building targets: public_interface_to_open_of_foo.cmx
   [INFO] [foo v0.1.0] Building targets: foo.cmi, foo.cmt
   [INFO] [foo v0.1.0] Building targets: lib.cmxa, lib.a
    Finished debug build of package: 'foo v0.1.0'

Change a file deep in the dependency graph and rebuild. Only the path through
the dependency graph from this file to the output should be rebuilt:
  $ cat > src/foo_dep.ml <<EOF
  > let message = "Hi"
  > EOF

  $ alice build --normalize-paths --verbose -j1
   [INFO] [foo v0.1.0] Loading ocamldeps cache from: build/packages/foo-0.1.0/ocamldeps_cache.marshal
   [INFO] [foo v0.1.0] Analyzing dependencies of file: src/foo_dep.ml
   Compiling foo v0.1.0
   [INFO] [foo v0.1.0] Building targets: foo_dep.cmt, foo_dep.cmx
   [INFO] [foo v0.1.0] Building targets: foo.cmt, foo.cmx
   [INFO] [foo v0.1.0] Building targets: lib.cmi, lib.cmt, lib.cmx
   [INFO] [foo v0.1.0] Building targets: main.cmi, main.cmt, main.cmx
   [INFO] [foo v0.1.0] Building targets: internal_modules_of_foo.cmx
   [INFO] [foo v0.1.0] Building targets: foo
   [INFO] [foo v0.1.0] Building targets: public_interface_to_open_of_foo.cmx
   [INFO] [foo v0.1.0] Building targets: foo.cmi, foo.cmt
   [INFO] [foo v0.1.0] Building targets: lib.cmxa, lib.a
    Finished debug build of package: 'foo v0.1.0'

Change a shallow dependency and rebuild. Only the final build steps should run:
  $ cat > src/main.ml <<EOF
  > let () = print_endline (Printf.sprintf "%s...%s!" Foo.hello Bar.world)
  > EOF

  $ alice build --normalize-paths --verbose -j1
   [INFO] [foo v0.1.0] Loading ocamldeps cache from: build/packages/foo-0.1.0/ocamldeps_cache.marshal
   [INFO] [foo v0.1.0] Analyzing dependencies of file: src/main.ml
   Compiling foo v0.1.0
   [INFO] [foo v0.1.0] Building targets: main.cmi, main.cmt, main.cmx
   [INFO] [foo v0.1.0] Building targets: foo
    Finished debug build of package: 'foo v0.1.0'

Change an interface and rebuild:
  $ cat > src/foo.mli <<EOF
  > (* a comment *)
  > val hello : string
  > EOF

  $ alice build --normalize-paths --verbose -j1
   [INFO] [foo v0.1.0] Loading ocamldeps cache from: build/packages/foo-0.1.0/ocamldeps_cache.marshal
   [INFO] [foo v0.1.0] Analyzing dependencies of file: src/foo.mli
   Compiling foo v0.1.0
   [INFO] [foo v0.1.0] Building targets: foo.cmi, foo.cmti
   [INFO] [foo v0.1.0] Building targets: foo.cmt, foo.cmx
   [INFO] [foo v0.1.0] Building targets: lib.cmi, lib.cmt, lib.cmx
   [INFO] [foo v0.1.0] Building targets: main.cmi, main.cmt, main.cmx
   [INFO] [foo v0.1.0] Building targets: internal_modules_of_foo.cmx
   [INFO] [foo v0.1.0] Building targets: foo
   [INFO] [foo v0.1.0] Building targets: public_interface_to_open_of_foo.cmx
   [INFO] [foo v0.1.0] Building targets: foo.cmi, foo.cmt
   [INFO] [foo v0.1.0] Building targets: lib.cmxa, lib.a
    Finished debug build of package: 'foo v0.1.0'
