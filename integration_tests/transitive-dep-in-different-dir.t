Exercise the use case where a repo of interdependent libraries are in one
directory and a project depending on some of them is in a separate directory.

Make a repo directory with some interdependent libraries:
  $ mkdir repo
  $ cd repo
  $ alice new --lib foo --normalize-paths --hide-time
   Creating new library package "foo" in foo
  $ alice new --lib bar --normalize-paths --hide-time
   Creating new library package "bar" in bar
  $ alice new --lib baz --normalize-paths --hide-time
   Creating new library package "baz" in baz

  $ echo 'let foo = `Foo (Bar.bar, Baz.baz)' > foo/src/lib.ml
  $ sed -i '/dependencies/abar path="../bar"\nbaz path="../baz"' foo/Alice.kdl

  $ echo 'let bar = `Bar Baz.baz' > bar/src/lib.ml
  $ sed -i '/dependencies/abaz path="../baz"' bar/Alice.kdl

  $ echo 'let baz = `Baz' > baz/src/lib.ml

  $ cd ..

Make a project that depends on one of the libraries:
  $ mkdir projects
  $ cd projects
  $ alice new --exe project --normalize-paths --hide-time
   Creating new executable package "project" in project
  $ cd project
  $ sed -i '/dependencies/afoo path="../../repo/foo"' Alice.kdl
  $ echo 'let () = let `Foo _ = Foo.foo in print_endline "hello"' > src/main.ml
  $ alice run --normalize-paths --hide-time
   Building baz v0.1.0 (native, debug)
   Building bar v0.1.0 (native, debug)
   Building foo v0.1.0 (native, debug)
   Building project v0.1.0 (native, debug)
      Built project v0.1.0 (native, debug)
    Running project v0.1.0
  
  hello
