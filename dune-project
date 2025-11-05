(lang dune 3.20)

(package
 (name alice)
 (depends ocaml climate sha))

(package
 (name alice_engine)
 (depends ocaml))

(package
 (name alice_error)
 (depends ocaml))

(package
 (name alice_io)
 (depends ocaml))

(package
 (name alice_log)
 (depends ocaml))

(package
 (name alice_env)
 (depends ocaml))

(package
 (name alice_package)
 (depends ocaml))

(package
 (name alice_package_meta)
 (depends ocaml))

(package
 (name alice_manifest)
 (depends ocaml toml))

(package
 (name alice_ocamldep)
 (depends ocaml))

(package
 (name alice_print)
 (depends ocaml))

(package
 (name alice_hierarchy)
 (depends ocaml))

(package
 (name alice_dag)
 (depends ocaml))

(package
 (name alice_graphviz)
 (depends ocaml))

(package
 (name alice_install_dir)
 (depends ocaml))

(package
 (name alice_which)
 (depends ocaml))

(package
 (name alice_ui)
 (depends ocaml))

(package
 (name alice_stdlib)
 (depends ocaml dyn fileutils pp re xdg))
