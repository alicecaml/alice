final: prev: {
  alicecaml = prev.alicecaml.overrideScope (ofinal: oprev: {
    dev-shell = ofinal.callPackage ../package/dev-shell.nix { };
  });
}
