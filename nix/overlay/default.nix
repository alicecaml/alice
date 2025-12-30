final: prev: {
  alicecaml = final.lib.makeScope final.newScope (self: {
    makeAlice = attrs: self.callPackage ../package/alice.nix attrs;

    alice = self.makeAlice { };

    tools = self.callPackage ../package/tools.nix { };

    default = self.alice;

    __functor = _: self.alice;
  });

  ocamlPackages = prev.ocamlPackages.overrideScope (
    ofinal: oprev: {
      climate = ofinal.buildDunePackage (finalAttrs: {
        pname = "climate";
        version = "0.9.0";
        src = final.fetchgit {
          url = "https://github.com/gridbugs/climate";
          rev = "refs/tags/${finalAttrs.version}";
          hash = "sha256-WRhWNWQ4iTUVpJlp7isJs3+0n/D0gYXTxRcCTJZ1o8U=";
        };
      });
    }
  );
}
