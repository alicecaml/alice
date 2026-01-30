(lang dune 3.20)

(generate_opam_files)

(name alice)

(source
 (github alicecaml/alice))

(homepage https://alicecaml.org)

(license MIT)

(authors "Stephen Sherratt <stephen@sherra.tt>")

(maintainers "Stephen Sherratt <stephen@sherra.tt>")

(cram enable)

(package
 (name alice)
 (synopsis "Radical OCaml build system and environment manager")
 (description
  "Alice is a radical, experimental OCaml build system, package manager, and toolchain manager for Windows, macOS, and Linux. Its goal is to allow anyone to program in OCaml with as little friction as possible.")
 (depends
  (ocaml
   (>= "5.1"))
  (climate
   (>= "0.9"))
  sha
  dyn
  fileutils
  pp
  (re
   (>= "1.12"))
  xdg
  (kdl
   (>= "0.2"))
  eio_main))

(package
 (name alice_tests)
 (depends ppx_inline_test ppx_expect))
