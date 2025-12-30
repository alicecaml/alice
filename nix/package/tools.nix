{ ocaml, ocamlformat_0_27_0, ocamlPackages, symlinkJoin, }:

symlinkJoin {
  name = "alice-ocaml-tools";
  paths = [
    ocaml
    ocamlformat_0_27_0
    ocamlPackages.ocaml-lsp
    ocamlPackages.dot-merlin-reader
  ];
}
