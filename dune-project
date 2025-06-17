(lang dune 3.20)

(package
 (name spice)
 (depends ocaml spice_engine))

(package
 (name spice_engine)
 (depends ocaml))

(package
 (name spice_policy)
 (depends ocaml))

(package
 (name spice_stdlib)
 (depends ocaml))
