final: prev: {
  alice = prev.alice.overrideScope (
    final': prev': {
      dev-shell = final'.callPackage ../package/dev-shell.nix { };
    }
  );
}
