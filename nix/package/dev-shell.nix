{ graphviz, pkgsMusl, }:

pkgsMusl.mkShell {
  nativeBuildInputs = [ graphviz ];
  buildInputs = [ pkgsMusl.musl ];
}
