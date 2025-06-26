let () =
  let x = Digestif.SHA256.get in
  ()
;;

module Url = struct
  type t = string
end

module Remote_tarball = struct
  type t =
    { url : Url.t
    ; top_level_dir : string
    }

  let create ~url ~top_level_dir = { url; top_level_dir }
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
    ; ocamllsp =
        rt
          ~url:
            "https://s3.g.s4.mega.io/ycsnsngpe2elgjdd2uzbdpyj6s54q5itlvy6g/alice/tools/ocamllsp/ocamllsp-macos-aarch64.1.22.0-built-with-ocaml.5.3.1%2Brelocatable.tar.gz"
          ~top_level_dir:"ocamllsp.1.22.0-built-with-ocaml.5.3.1+relocatable"
    ; ocamlformat =
        rt
          ~url:
            "https://s3.g.s4.mega.io/ycsnsngpe2elgjdd2uzbdpyj6s54q5itlvy6g/alice/tools/ocamlformat/ocamlformat-macos-aarch64.0.27.0-built-with-ocaml.5.3.1%2Brelocatable.tar.gz"
          ~top_level_dir:"ocamlformat.0.27.0-built-with-ocaml.5.3.1+relocatable"
    }
  ;;
end
