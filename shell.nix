{ pkgs ? import <nixpkgs> { } }:
let muslPkgs = pkgs.pkgsMusl;
in muslPkgs.mkShell { buildIpnuts = with muslPkgs; [ musl ]; }
