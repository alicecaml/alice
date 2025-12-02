{ pkgs ? import <nixpkgs> { } }:
# When developing alice, use the musl toolchain. The development
# environment (ocamllsp, ocamlopt, etc) can then be managed by alice
# itself, since alice can install tools which have been pre-compiled
# against musl. This lets us dogfood alice's tool installation
# mechanism, and allows alice to be built with dune package
# management on NixOS, where the OCaml compiler is treated as a
# package and thus a specific version unknown to nix is fixed in the
# lockdir.
let muslPkgs = pkgs.pkgsMusl;
in muslPkgs.mkShell {
  nativeBuildInputs = [ pkgs.graphviz ];
  buildIpnuts = [ muslPkgs.musl ];
}
