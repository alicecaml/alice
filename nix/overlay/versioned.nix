final: prev: {
  alicecaml =
    let
      versioned =
        final.lib.mapAttrs
          (
            _:
            { version, hash }:
            let
              aliceWithoutTools =
                (final.alicecaml.makeAlice { inherit version; }).overrideAttrs (old: {
                  src = final.fetchgit {
                    inherit hash;
                    url = "https://github.com/alicecaml/alice";
                    rev = "refs/tags/${version}";
                  };
                });
              aliceWithTools = final.alicecaml.addTools aliceWithoutTools;
            in
            {
              inherit aliceWithoutTools aliceWithTools;
              default = aliceWithTools;
            }
          )
          {
            "0_1_0" = {
              version = "0.1.0";
              hash = "sha256-Ax9qbFzgHPH0EYQrgA+1bEAlFinc4egNKIn/ZrxV5K4=";
            };
            "0_1_1" = {
              version = "0.1.1";
              hash = "sha256-4T6YyyN4ttFcqSeBWNfff8bL7bYWYhLMxqRN7KCAp3c=";
            };
            "0_1_2" = {
              version = "0.1.2";
              hash = "sha256-05EXQxosue5XEwAUtkI/2VObKJzUTzrZfVH3WELHACk=";
            };
            "0_1_3" = {
              version = "0.1.3";
              hash = "sha256-PkZbzqjlWswJ/8wBJikj45royPUEyUWG/bRqB47qkXg=";
            };
            "0_2_0" = {
              version = "0.2.0";
              hash = "sha256-QNAPIccp3K6w0s35jmEWodwvac0YoWUZr0ffXptfLGs=";
            };
            "0_3_0" = {
              version = "0.3.0";
              hash = "sha256-7KvoTQOHgd5cWMCw2EKbxSa45mqYLklEF8vvIzgwAeY=";
            };

          };
    in
    prev.alicecaml.overrideScope (
      ofinal: oprev: {
        versioned = versioned // {
          latest = versioned."0_3_0";
        };
      }
    );
}
