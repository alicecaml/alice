{
  description =
    "Alice is a radical, experimental OCaml build system, package manager, and toolchain manager for Windows and Unix-based OSes.";

  inputs = { nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable"; };

  outputs = { self, nixpkgs }:
    let
      systems =
        [ "aarch64-darwin" "aarch64-linux" "x86_64-darwin" "x86_64-linux" ];
      nixpkgsFor = nixpkgs.lib.genAttrs systems (system:
        import nixpkgs {
          inherit system;
          config = { };
          overlays = [
            (import ./nix/overlay/default.nix)
            (import ./nix/overlay/development.nix)
            (import ./nix/overlay/versioned.nix)
          ];
        });
      forAllSystems = fn:
        nixpkgs.lib.genAttrs systems (system:
          fn rec {
            inherit system;
            pkgs = nixpkgsFor.${system};
            inherit (pkgs) lib;
          });
    in {
      overlays = {
        default = import ./nix/overlay/default.nix;
        development = import ./nix/overlay/development.nix;
        versioned = import ./nix/overlay/versioned.nix;
      };

      packages = forAllSystems ({ pkgs, lib, ... }:
        let
          prefix = name: value: {
            inherit value;
            name = "alice_" + name;
          };
        in lib.mapAttrs' prefix pkgs.alicecaml.versioned // {
          inherit (pkgs.alicecaml) tools;

          # By default, get the latest released version of Alice.
          default = pkgs.alicecaml.versioned.latest.default;
          alice_dev = pkgs.alicecaml;
        });

      devShells =
        forAllSystems ({ pkgs, ... }: { default = pkgs.alicecaml.dev-shell; });
    };
}
