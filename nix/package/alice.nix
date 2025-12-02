{
  lib,
  ocamlPackages,
  fetchgit,
  withBashCompletions ? true,
}:

ocamlPackages.buildDunePackage {
  pname = "alice";
  version = "0.3-dev";

  src =
    let
      fs = lib.fileset;

      ocaml-project =
        file:
        lib.lists.elem file.name [
          "dune-project"
          "dune-workspace"
        ]
        || file.hasExt "opam";

      ocaml-src =
        file:
        file.name == "dune"
        || lib.lists.any file.hasExt [
          "ml"
          "mld"
          "mli"
          "mly"
        ];
    in
    fs.toSource {
      root = ../..;
      fileset = fs.unions [
        (fs.fileFilter ocaml-project ../..)
        (fs.fileFilter ocaml-src ../..)
      ];
    };

  buildInputs = with ocamlPackages; [
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

  postInstall = lib.optionalString withBashCompletions /* sh */ ''
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

  meta = {
    license = with lib.licenses; [ mit ];
  };
}
