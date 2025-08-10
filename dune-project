(lang dune 3.20)

(pin
 (url
  "git+https://github.com/gridbugs/climate#2ab398071e39516a66b84071e80c8243bdf199c0")
 (package
  (name climate)))

(package
 (name alice)
 (depends ocaml climate sha))

(package
 (name alice_demo)
 (depends ocaml))

(package
 (name alice_engine)
 (depends ocaml))

(package
 (name alice_error)
 (depends ocaml alice_stdlib))

(package
 (name alice_io)
 (depends ocaml))

(package
 (name alice_log)
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
 (name alice_ocamldep)
 (depends ocaml))

(package
 (name alice_print)
 (depends ocaml))

(package
 (name alice_project)
 (depends ocaml))

(package
 (name alice_policy)
 (depends ocaml))

(package
 (name alice_hierarchy)
 (depends ocaml))

(package
 (name alice_scheduler)
 (depends ocaml))

(package
 (name alice_stdlib)
 (depends
  ocaml
  (dyn
   (and
    (>= 3)
    (< 4)))
  (fileutils
   (and
    (>= 0.6)
    (< 0.7)))
  (ordering
   (and
    (>= 3)
    (< 4)))
  (pp
   (and
    (>= 2)
    (< 3)))
  (re
   (and
    (>= 1)
    (< 2)))
  (xdg
   (and
    (>= 3)
    (< 4)))))
