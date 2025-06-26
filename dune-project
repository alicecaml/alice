(lang dune 3.20)

(package
 (name alice)
 (depends ocaml climate digestif))

(package
 (name alice_demo)
 (depends ocaml))

(package
 (name alice_engine)
 (depends ocaml))

(package
 (name alice_io)
 (depends ocaml))

(package
 (name alice_manifest)
 (depends
  ocaml
  (toml
   (and
    (>= 7)
    (< 8)))))

(package
 (name alice_policy)
 (depends ocaml))

(package
 (name alice_hierarchy)
 (depends ocaml))

(package
 (name alice_stdlib)
 (depends
  ocaml
  (dyn
   (and
    (>= 3)
    (< 4)))
  (ordering
   (and
    (>= 3)
    (< 4)))
  (pp
   (and
    (>= 2)
    (< 3)))))
