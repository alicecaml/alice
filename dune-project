(lang dune 3.20)

(package
 (name spice)
 (depends ocaml))

(package
 (name spice_demo)
 (depends ocaml))

(package
 (name spice_engine)
 (depends ocaml))

(package
 (name spice_io)
 (depends ocaml))

(package
 (name spice_manifest)
 (depends
  ocaml
  (toml
   (and
    (>= 7)
    (< 8)))))

(package
 (name spice_policy)
 (depends ocaml))

(package
 (name spice_hierarchy)
 (depends ocaml))

(package
 (name spice_stdlib)
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
