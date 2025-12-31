{ lib, ocamlPackages, withBashCompletions ? true,
# Overriding the version of a derivation produced by buildDunePackage doesn't
# result in the new version appearing in the output, so alternative versions
# must be passed as arguments instead.
version ? "0.4-dev", }:

ocamlPackages.buildDunePackage {
  pname = "alice";
  inherit version;

  src = let
    fs = lib.fileset;

    ocaml-project = file:
      lib.lists.elem file.name [ "dune-project" "dune-workspace" ]
      || file.hasExt "opam";

    ocaml-src = file:
      file.name == "dune"
      || lib.lists.any file.hasExt [ "ml" "mld" "mli" "mly" ];
  in fs.toSource {
    root = ../..;
    fileset = fs.unions [
      (fs.fileFilter ocaml-project ../..)
      (fs.fileFilter ocaml-src ../..)
    ];
  };

  buildInputs = with ocamlPackages; [
    sha
    xdg
    kdl
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
    climate
  ];

  postInstall = lib.optionalString withBashCompletions # sh
    ''
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
    mainProgram = "alice";
  };
}
