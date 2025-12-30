final: prev: {
  alicecaml = prev.alicecaml.overrideScope (
    final': prev': {
      dev-shell = final'.callPackage ../package/dev-shell.nix { };
    }
  );
}
