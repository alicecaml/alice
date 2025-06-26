open! Alice_stdlib

module Url = struct
  type t = string
end

module Remote_tarball = struct
  type t =
    { url : Url.t
    ; top_level_dir : string
    ; sha256 : Sha256.t
    }

  let create ~url ~top_level_dir ~sha256 = { url; top_level_dir; sha256 }
end

module Remote_tarballs = struct
  type t =
    { compiler : Remote_tarball.t
    ; ocamllsp : Remote_tarball.t
    ; ocamlformat : Remote_tarball.t
    }

  let rt = Remote_tarball.create

  (* Just hard-code these for now to keep things simple! *)
  let macos_aarch64_latest =
    { compiler =
        rt
          ~url:
            "https://s3.g.s4.mega.io/ycsnsngpe2elgjdd2uzbdpyj6s54q5itlvy6g/alice/compilers/ocaml-macos-aarch64.5.3.1%2Brelocatable.tar.gz"
          ~top_level_dir:"ocaml.5.3.1+relocatable"
          ~sha256:
            (Sha256.of_hex
               "3d88de1ecb28a2071c843a8faf6e8bbfa54ca704b7915b61f982d3286e59929d")
    ; ocamllsp =
        rt
          ~url:
            "https://s3.g.s4.mega.io/ycsnsngpe2elgjdd2uzbdpyj6s54q5itlvy6g/alice/tools/ocamllsp/ocamllsp-macos-aarch64.1.22.0-built-with-ocaml.5.3.1%2Brelocatable.tar.gz"
          ~top_level_dir:"ocamllsp.1.22.0-built-with-ocaml.5.3.1+relocatable"
          ~sha256:
            (Sha256.of_hex
               "6986bc8d8c8e0a10345faaa9ed198419a0e62845d03e68ce0bedf8465841a07d")
    ; ocamlformat =
        rt
          ~url:
            "https://s3.g.s4.mega.io/ycsnsngpe2elgjdd2uzbdpyj6s54q5itlvy6g/alice/tools/ocamlformat/ocamlformat-macos-aarch64.0.27.0-built-with-ocaml.5.3.1%2Brelocatable.tar.gz"
          ~top_level_dir:"ocamlformat.0.27.0-built-with-ocaml.5.3.1+relocatable"
          ~sha256:
            (Sha256.of_hex
               "28821b4d1aada07e5f8cca47c27a2f238219b70ee898bf905e4d6e8cf14b5808")
    }
  ;;
end
