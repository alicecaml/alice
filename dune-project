(lang dune 3.20)

(generate_opam_files)

(name alice)

(source
 (github alicecaml/alice))

(license MIT)

(authors "Stephen Sherratt <stephen@sherra.tt>")

(maintainers "Stephen Sherratt <stephen@sherra.tt>")

(cram enable)

(package
 (name alice)
 (synopsis "Radical OCaml build system and environment manager")
 (depends ocaml climate sha dyn fileutils pp re xdg toml))
