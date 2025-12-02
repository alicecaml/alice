{
  description =
    "Alice is a radical, experimental OCaml build system, package manager, and toolchain manager for Windows and Unix-based OSes.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let pkgs = import nixpkgs { inherit system; };
      in {
        packages = pkgs.callPackage ./default.nix { };
        devShell = (import ./shell.nix { inherit pkgs; });
      });
}
