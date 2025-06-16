(lang dune 3.20)

(package
 (name spice_engine)
 (depends ocaml))

(package
 (name spice)
 (depends ocaml spice_engine))
