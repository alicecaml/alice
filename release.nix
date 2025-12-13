let
  flake_lock = builtins.fromJSON (builtins.readFile ./flake.lock);

  pkgs-src = builtins.fetchTarball {
    url =
      flake_lock.nodes.nixpkgs.locked.url
        or "https://github.com/NixOS/nixpkgs/archive/${flake_lock.nodes.nixpkgs.locked.rev}.tar.gz";
    sha256 = flake_lock.nodes.nixpkgs.locked.narHash;
  };

  pkgs = import pkgs-src {
    overlays = [
      (import ./nix/overlay/default.nix)
      (import ./nix/overlay/development.nix)
      (import ./nix/overlay/versioned.nix)
    ];
  };
in
{
  inherit (pkgs.alice) alice default tools versioned;

  # When developing alice, use the musl toolchain. The development environment
  # (ocamllsp, ocamlopt, etc.) can then be managed by alice itself, since alice
  # can install tools which have been pre-compiled against musl. This lets us
  # dogfood alice’s tool installation mechanism, and allows alice to be built
  # with dune package management on NixOS, where the OCaml compiler is treated
  # as a package and thus a specific version unknown to nix is fixed in the
  # lockdir.
  inherit (pkgs.pkgsMusl.alice) dev-shell;
}
