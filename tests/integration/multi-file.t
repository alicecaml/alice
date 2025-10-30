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
    "build/debug/packages/foo-0.1.0/bar.cmx" -> {"src/bar.ml"}
    "build/debug/packages/foo-0.1.0/bar.o" -> {"src/bar.ml"}
    "build/debug/packages/foo-0.1.0/foo" -> {"build/debug/packages/foo-0.1.0/bar.cmx", "build/debug/packages/foo-0.1.0/bar.o", "build/debug/packages/foo-0.1.0/foo.cmx", "build/debug/packages/foo-0.1.0/foo.o", "build/debug/packages/foo-0.1.0/foo_dep.cmx", "build/debug/packages/foo-0.1.0/foo_dep.o", "build/debug/packages/foo-0.1.0/main.cmx", "build/debug/packages/foo-0.1.0/main.o"}
    "build/debug/packages/foo-0.1.0/foo.cmi" -> {"src/foo.mli"}
    "build/debug/packages/foo-0.1.0/foo.cmx" -> {"build/debug/packages/foo-0.1.0/foo.cmi", "build/debug/packages/foo-0.1.0/foo_dep.cmx", "src/foo.ml"}
    "build/debug/packages/foo-0.1.0/foo.o" -> {"build/debug/packages/foo-0.1.0/foo.cmi", "build/debug/packages/foo-0.1.0/foo_dep.cmx", "src/foo.ml"}
    "build/debug/packages/foo-0.1.0/foo_dep.cmi" -> {"src/foo_dep.mli"}
    "build/debug/packages/foo-0.1.0/foo_dep.cmx" -> {"build/debug/packages/foo-0.1.0/foo_dep.cmi", "src/foo_dep.ml"}
    "build/debug/packages/foo-0.1.0/foo_dep.o" -> {"build/debug/packages/foo-0.1.0/foo_dep.cmi", "src/foo_dep.ml"}
    "build/debug/packages/foo-0.1.0/main.cmx" -> {"build/debug/packages/foo-0.1.0/bar.cmx", "build/debug/packages/foo-0.1.0/foo.cmx", "src/main.ml"}
    "build/debug/packages/foo-0.1.0/main.o" -> {"build/debug/packages/foo-0.1.0/bar.cmx", "build/debug/packages/foo-0.1.0/foo.cmx", "src/main.ml"}
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
   [INFO] [foo v0.1.0] Analyzing dependencies of file: src/bar.ml
   [INFO] [foo v0.1.0] Analyzing dependencies of file: src/foo.ml
   [INFO] [foo v0.1.0] Analyzing dependencies of file: src/foo.mli
   [INFO] [foo v0.1.0] Analyzing dependencies of file: src/foo_dep.ml
   [INFO] [foo v0.1.0] Analyzing dependencies of file: src/foo_dep.mli
   [INFO] [foo v0.1.0] Analyzing dependencies of file: src/main.ml
   Compiling foo v0.1.0
   [INFO] [foo v0.1.0] Building targets: build/debug/packages/foo-0.1.0/bar.cmx, build/debug/packages/foo-0.1.0/bar.o
   [INFO] [foo v0.1.0] Building targets: build/debug/packages/foo-0.1.0/foo.cmi
   [INFO] [foo v0.1.0] Building targets: build/debug/packages/foo-0.1.0/foo_dep.cmi
   [INFO] [foo v0.1.0] Building targets: build/debug/packages/foo-0.1.0/foo_dep.cmx, build/debug/packages/foo-0.1.0/foo_dep.o
   [INFO] [foo v0.1.0] Building targets: build/debug/packages/foo-0.1.0/foo.cmx, build/debug/packages/foo-0.1.0/foo.o
   [INFO] [foo v0.1.0] Building targets: build/debug/packages/foo-0.1.0/main.cmx, build/debug/packages/foo-0.1.0/main.o
   [INFO] [foo v0.1.0] Building targets: build/debug/packages/foo-0.1.0/foo

Change a file deep in the dependency graph and rebuild. Only the path through
the dependency graph from this file to the output should be rebuilt:
  $ cat > src/foo_dep.ml <<EOF
  > let message = "Hi"
  > EOF

  $ alice build --normalize-paths --verbose
   [INFO] [foo v0.1.0] Loading ocamldeps cache from: ocamldeps_cache.marshal
   [INFO] [foo v0.1.0] Analyzing dependencies of file: src/foo_dep.ml
   Compiling foo v0.1.0
   [INFO] [foo v0.1.0] Building targets: build/debug/packages/foo-0.1.0/foo_dep.cmx, build/debug/packages/foo-0.1.0/foo_dep.o
   [INFO] [foo v0.1.0] Building targets: build/debug/packages/foo-0.1.0/foo.cmx, build/debug/packages/foo-0.1.0/foo.o
   [INFO] [foo v0.1.0] Building targets: build/debug/packages/foo-0.1.0/main.cmx, build/debug/packages/foo-0.1.0/main.o
   [INFO] [foo v0.1.0] Building targets: build/debug/packages/foo-0.1.0/foo

Change a shallow dependency and rebuild. Only the final build steps should run:
  $ cat > src/main.ml <<EOF
  > let () = print_endline (Printf.sprintf "%s...%s!" Foo.hello Bar.world)
  > EOF

  $ alice build --normalize-paths --verbose
   [INFO] [foo v0.1.0] Loading ocamldeps cache from: ocamldeps_cache.marshal
   [INFO] [foo v0.1.0] Analyzing dependencies of file: src/main.ml
   Compiling foo v0.1.0
   [INFO] [foo v0.1.0] Building targets: build/debug/packages/foo-0.1.0/main.cmx, build/debug/packages/foo-0.1.0/main.o
   [INFO] [foo v0.1.0] Building targets: build/debug/packages/foo-0.1.0/foo

Change an interface and rebuild:
  $ cat > src/foo.mli <<EOF
  > (* a comment *)
  > val hello : string
  > EOF

  $ alice build --normalize-paths --verbose
   [INFO] [foo v0.1.0] Loading ocamldeps cache from: ocamldeps_cache.marshal
   [INFO] [foo v0.1.0] Analyzing dependencies of file: src/foo.mli
   Compiling foo v0.1.0
   [INFO] [foo v0.1.0] Building targets: build/debug/packages/foo-0.1.0/foo.cmi
   [INFO] [foo v0.1.0] Building targets: build/debug/packages/foo-0.1.0/foo.cmx, build/debug/packages/foo-0.1.0/foo.o
   [INFO] [foo v0.1.0] Building targets: build/debug/packages/foo-0.1.0/main.cmx, build/debug/packages/foo-0.1.0/main.o
   [INFO] [foo v0.1.0] Building targets: build/debug/packages/foo-0.1.0/foo
