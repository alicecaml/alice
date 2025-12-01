{
  description = "Alice";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        tools = pkgs.symlinkJoin {
          name = "alice-ocaml-tools";
          paths = with pkgs; [
            ocaml
            ocamlPackages.ocaml-lsp
            ocamlPackages.dot-merlin-reader
            ocamlformat_0_27_0
          ];
        };
        deps = with pkgs.ocamlPackages; [
          sha
          xdg
          toml
          re
          fileutils
          pp
          (dyn.overrideAttrs (_: {
            # Since alice depends on pp and dyn, modify dyn to reuse the common
            # pp rather than vendoring it. This avoids a module conflict
            # between pp and dyn's vendored copy of pp when building alice.
            buildInputs = [ pp ];
            patchPhase = ''
              rm -rf vendor/pp
            '';
          }))
          (buildDunePackage {
            pname = "climate";
            version = "0.9.0";
            src = fetchGit {
              url = "https://github.com/gridbugs/climate";
              ref = "0.9.0";
              rev = "49e24c3f063ba8877d9ed0b332e1b1c5fec41d12";
            };
          })
        ];
        aliceMin = pkgs.ocamlPackages.buildDunePackage {
          pname = "alice";
          version = "0.2.0";
          src = ./.;
          buildInputs = deps;
        };
        aliceBashCompletion = pkgs.runCommand "alice-bash-completion" { } ''
          mkdir -p $out/share/bash-completion/completions
          ${aliceMin}/bin/alice internal completions bash \
            --program-name=alice \
            --program-exe-for-reentrant-query=alice \
            --global-symbol-prefix=__alice \
            --no-command-hash-in-function-names \
            --no-comments \
            --no-whitespace \
            --minify-global-names \
            --minify-local-variables \
            --optimize-case-statements > $out/share/bash-completion/completions/alice
        '';
        alice = pkgs.symlinkJoin {
          name = "alice";
          version = aliceMin.version;
          paths = [ aliceMin aliceBashCompletion ];
        };
        full = pkgs.symlinkJoin {
          name = "alice-and-ocaml-tools";
          paths = [ alice tools ];
        };
      in {
        packages = {
          inherit tools alice full;
          default = full;
        };
        devShell =
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
            buildInputs = [ muslPkgs.musl ];
          };
      });
}
