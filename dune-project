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
  ; The upper bound on the compiler version is a workaround for issues solving
  ; dependencies with Dune when OCaml 5.5 is chosen by the solver. The error is of the form:
  ;
  ; File "packages/ocaml-compiler/ocaml-compiler.5.5.2/opam", line 1, characters 0-0:
  ; Error: Variable "build-id" is not supported.
  ;
  ; There's no reason Alice couldn't be built with a more recent compiler if it
  ; could be installed via some other means.
  (ocaml
   (and
    (>= "5.1")
    (< "5.5")))
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
   (>= "0.2"))))

(package
 (name alice_tests)
 (depends ppx_inline_test ppx_expect))
