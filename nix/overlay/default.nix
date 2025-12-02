final: prev: {
  alice = final.lib.makeScope final.newScope (self: {
    alice = self.callPackage ../package/alice.nix { };

    default = self.alice;

    __functor = _: self.alice;
  });
}
