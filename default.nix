{ ocaml, ocamlformat_0_27_0, ocamlPackages, fetchgit, symlinkJoin }:
let
  tools = symlinkJoin {
    name = "alice-ocaml-tools";
    paths = [
      ocaml
      ocamlPackages.ocaml-lsp
      ocamlPackages.dot-merlin-reader
      ocamlformat_0_27_0
    ];
  };
  deps = with ocamlPackages; [
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
      src = fetchgit {
        url = "https://github.com/gridbugs/climate";
        rev = "refs/tags/0.9.0";
        hash = "sha256-WRhWNWQ4iTUVpJlp7isJs3+0n/D0gYXTxRcCTJZ1o8U=";
      };
    })
  ];
  make = { version, src }:
    let
      packageBare = (ocamlPackages.buildDunePackage {
        inherit src;
        pname = "alice";
        version = version;
        buildInputs = deps;
        postInstall = ''
          mkdir -p $out/share/bash-completion/completions
          $out/bin/alice internal completions bash \
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
      });
      packageWithTools = symlinkJoin {
        name = "alice-${version}-and-ocaml-tools";
        version = version;
        paths = [ packageBare tools ];
      };
    in packageWithTools // { bare = packageBare; };
  makeGithub = { version, hash }:
    make {
      inherit version;
      src = fetchgit {
        url = "https://github.com/alicecaml/alice";
        rev = "refs/tags/${version}";
        hash = hash;
      };
    };
  versioned = {
    alice_0_1_0 = makeGithub {
      version = "0.1.0";
      hash = "sha256-Ax9qbFzgHPH0EYQrgA+1bEAlFinc4egNKIn/ZrxV5K4=";
    };
    alice_0_1_1 = makeGithub {
      version = "0.1.1";
      hash = "sha256-4T6YyyN4ttFcqSeBWNfff8bL7bYWYhLMxqRN7KCAp3c=";
    };
    alice_0_1_2 = makeGithub {
      version = "0.1.2";
      hash = "sha256-05EXQxosue5XEwAUtkI/2VObKJzUTzrZfVH3WELHACk=";
    };
    alice_0_1_3 = makeGithub {
      version = "0.1.3";
      hash = "sha256-PkZbzqjlWswJ/8wBJikj45royPUEyUWG/bRqB47qkXg=";
    };
    alice_0_2_0 = makeGithub {
      version = "0.2.0";
      hash = "sha256-QNAPIccp3K6w0s35jmEWodwvac0YoWUZr0ffXptfLGs=";
    };
  };
  latest = versioned.alice_0_2_0;
  dev = make {
    version = "0.3-dev";
    src = ./.;
  };
in {
  inherit versioned latest tools dev;
  default = latest;
}
