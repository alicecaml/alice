{
  description =
    "Alice is a radical, experimental OCaml build system, package manager, and toolchain manager for Windows and Unix-based OSes.";

  inputs = { nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable"; };

  outputs = { self, nixpkgs }:
    let
      overlays = {
        default = import ./nix/overlay/default.nix;
        development = import ./nix/overlay/development.nix;
        versioned = import ./nix/overlay/versioned.nix;
      };
      systems =
        [ "aarch64-darwin" "aarch64-linux" "x86_64-darwin" "x86_64-linux" ];
      nixpkgsFor = nixpkgs.lib.genAttrs systems (system:
        import nixpkgs {
          inherit system;
          config = { };
          overlays =
            [ overlays.default overlays.development overlays.versioned ];
        });
      forAllSystems = fn:
        nixpkgs.lib.genAttrs systems (system:
          fn rec {
            inherit system;
            pkgs = nixpkgsFor.${system};
            inherit (pkgs) lib;
          });
    in {
      inherit overlays;
      packages = forAllSystems ({ pkgs, lib, ... }:
        let
          prefix = name: value: {
            inherit value;
            name = "alice_" + name;
          };
        in lib.mapAttrs' prefix pkgs.alicecaml.versioned // {
          inherit (pkgs.alicecaml) tools;

          # By default get the current development version of Alice. This is so
          # that installing the flake from a versioned release tag installs
          # that version of Alice.
          default = pkgs.alicecaml.default;
        });

      devShells =
        forAllSystems ({ pkgs, ... }: { default = pkgs.alicecaml.dev-shell; });
    };
}
