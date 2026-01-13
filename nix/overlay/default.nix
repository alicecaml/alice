final: prev: {
  alicecaml = final.lib.makeScope final.newScope (self: {
    makeAlice = attrs: self.callPackage ../package/alice.nix attrs;

    aliceWithoutTools = self.makeAlice { version = "0.5-dev"; };

    tools = self.callPackage ../package/tools.nix { };

    # Create a derivation which is the union of a given alice derivation and
    # the OCaml tools.
    addTools = alice:
      let version = alice.version;
      in prev.symlinkJoin {
        name = "alice-${version}-with-ocaml-tools";
        version = version;
        paths = [ alice self.tools ];
      };

    aliceWithTools = self.addTools self.aliceWithoutTools;

    default = self.aliceWithTools;
  });

  ocamlPackages = prev.ocamlPackages.overrideScope (ofinal: oprev: {
    climate = ofinal.buildDunePackage (finalAttrs: {
      pname = "climate";
      version = "0.9.0";
      src = final.fetchgit {
        url = "https://github.com/gridbugs/climate";
        rev = "refs/tags/${finalAttrs.version}";
        hash = "sha256-WRhWNWQ4iTUVpJlp7isJs3+0n/D0gYXTxRcCTJZ1o8U=";
      };
    });
  });
}
