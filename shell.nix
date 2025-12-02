{ pkgs ? import <nixpkgs> { } }:
let muslPkgs = pkgs.pkgsMusl;
in muslPkgs.mkShell {
  nativeBuildInputs = [ pkgs.graphviz ];
  buildIpnuts = [ muslPkgs.musl ];
}
