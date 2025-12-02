final: prev: {
  alice = {
    package = final.callPackage ../package/alice.nix { };
  };
}
