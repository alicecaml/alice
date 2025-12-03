final: prev: {
  alice = {
    package = final.callPackage ../package/alice.nix { };
    tools = final.callPackage ../package/tools.nix { };
  };

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
