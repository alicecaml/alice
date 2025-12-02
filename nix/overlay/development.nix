final: prev: {
  alice = (prev.alice or { }) // {
    dev-shell = final.callPackage ../package/dev-shell.nix { };
  };
}
