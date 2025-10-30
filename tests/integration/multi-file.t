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

  $ cat > src/main.ml <<EOF
  > let () = print_endline (Printf.sprintf "%s, %s!" Foo.hello Bar.world)
  > EOF

  $ cat > Alice.toml <<EOF
  > [package]
  > name = "foo"
  > version = "0.1.0"
  > EOF

Print the dependency graph of the project:
  $ alice dot artifacts --normalize-paths
  digraph {
    "bar.cmx" -> {"bar.ml"}
    "bar.o" -> {"bar.ml"}
    "foo" -> {"bar.cmx", "bar.o", "foo.cmx", "foo.o", "foo_dep.cmx", "foo_dep.o", "main.cmx", "main.o"}
    "foo.cmi" -> {"foo.mli"}
    "foo.cmx" -> {"foo.cmi", "foo.ml", "foo_dep.cmx"}
    "foo.o" -> {"foo.cmi", "foo.ml", "foo_dep.cmx"}
    "foo_dep.cmi" -> {"foo_dep.mli"}
    "foo_dep.cmx" -> {"foo_dep.cmi", "foo_dep.ml"}
    "foo_dep.o" -> {"foo_dep.cmi", "foo_dep.ml"}
    "main.cmx" -> {"bar.cmx", "foo.cmx", "main.ml"}
    "main.o" -> {"bar.cmx", "foo.cmx", "main.ml"}
  }

Test that the project can be built an run:
  $ alice run --normalize-paths
   Compiling foo v0.1.0
     Running build/debug/packages/foo-0.1.0/foo
  
  Hello, World!

  $ alice clean --normalize-paths
    Removing build

Now test Alice's incremental recomputation by repeatedly changing files and
rebuilding the project.

Initial build:
  $ alice build --normalize-paths --verbose
   [INFO] [foo v0.1.0] Analyzing dependencies of file: bar.ml
   [INFO] [foo v0.1.0] Analyzing dependencies of file: foo.ml
   [INFO] [foo v0.1.0] Analyzing dependencies of file: foo.mli
   [INFO] [foo v0.1.0] Analyzing dependencies of file: foo_dep.ml
   [INFO] [foo v0.1.0] Analyzing dependencies of file: foo_dep.mli
   [INFO] [foo v0.1.0] Analyzing dependencies of file: main.ml
   Compiling foo v0.1.0
   [INFO] [foo v0.1.0] Copying source file: bar.ml
   [INFO] [foo v0.1.0] Building targets: bar.cmx, bar.o
   [INFO] [foo v0.1.0] Copying source file: foo.mli
   [INFO] [foo v0.1.0] Building targets: foo.cmi
   [INFO] [foo v0.1.0] Copying source file: foo.ml
   [INFO] [foo v0.1.0] Copying source file: foo_dep.mli
   [INFO] [foo v0.1.0] Building targets: foo_dep.cmi
   [INFO] [foo v0.1.0] Copying source file: foo_dep.ml
   [INFO] [foo v0.1.0] Building targets: foo_dep.cmx, foo_dep.o
   [INFO] [foo v0.1.0] Building targets: foo.cmx, foo.o
   [INFO] [foo v0.1.0] Copying source file: main.ml
   [INFO] [foo v0.1.0] Building targets: main.cmx, main.o
   [INFO] [foo v0.1.0] Building targets: foo

Change a file deep in the dependency graph and rebuild. Only the path through
the dependency graph from this file to the output should be rebuilt:
  $ cat > src/foo_dep.ml <<EOF
  > let message = "Hi"
  > EOF

  $ alice build --normalize-paths --verbose
   [INFO] [foo v0.1.0] Loading ocamldeps cache from: ocamldeps_cache.marshal
   [INFO] [foo v0.1.0] Analyzing dependencies of file: foo_dep.ml
   Compiling foo v0.1.0
   [INFO] [foo v0.1.0] Copying source file: foo_dep.ml
   [INFO] [foo v0.1.0] Building targets: foo_dep.cmx, foo_dep.o
   [INFO] [foo v0.1.0] Building targets: foo.cmx, foo.o
   [INFO] [foo v0.1.0] Building targets: main.cmx, main.o
   [INFO] [foo v0.1.0] Building targets: foo

Change a shallow dependency and rebuild. Only the final build steps should run:
  $ cat > src/main.ml <<EOF
  > let () = print_endline (Printf.sprintf "%s...%s!" Foo.hello Bar.world)
  > EOF

  $ alice build --normalize-paths --verbose
   [INFO] [foo v0.1.0] Loading ocamldeps cache from: ocamldeps_cache.marshal
   [INFO] [foo v0.1.0] Analyzing dependencies of file: main.ml
   Compiling foo v0.1.0
   [INFO] [foo v0.1.0] Copying source file: main.ml
   [INFO] [foo v0.1.0] Building targets: main.cmx, main.o
   [INFO] [foo v0.1.0] Building targets: foo

Change an interface and rebuild:
  $ cat > src/foo.mli <<EOF
  > (* a comment *)
  > val hello : string
  > EOF

  $ alice build --normalize-paths --verbose
   [INFO] [foo v0.1.0] Loading ocamldeps cache from: ocamldeps_cache.marshal
   [INFO] [foo v0.1.0] Analyzing dependencies of file: foo.mli
   Compiling foo v0.1.0
   [INFO] [foo v0.1.0] Copying source file: foo.mli
   [INFO] [foo v0.1.0] Building targets: foo.cmi
   [INFO] [foo v0.1.0] Building targets: foo.cmx, foo.o
   [INFO] [foo v0.1.0] Building targets: main.cmx, main.o
   [INFO] [foo v0.1.0] Building targets: foo
