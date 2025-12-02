{
  description =
    "Alice is a radical, experimental OCaml build system, package manager, and toolchain manager for Windows and Unix-based OSes.";

  inputs = { nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable"; };

  outputs = { self, nixpkgs }:
    let
      systems =
        [ "aarch64-darwin" "aarch64-linux" "x86_64-darwin" "x86_64-linux" ];
      mapSystemAttrs = f:
        builtins.listToAttrs (map (system: {
          name = system;
          value = f system;
        }) systems);
      getPkgs = system: builtins.getAttr system nixpkgs.legacyPackages;
      makePackage = system: (getPkgs system).callPackage ./default.nix { };
      makeDevShell =
        system: ({ default = import ./shell.nix { pkgs = getPkgs system; }; });
    in {
      packages = mapSystemAttrs makePackage;
      devShells = mapSystemAttrs makeDevShell;
    };
}
