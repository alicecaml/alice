open! Alice_stdlib
open Climate

let panic_if_hashes_don't_match path expected_hash =
  let actual_hash = Sha256.file path in
  if Sha256.equal actual_hash expected_hash
  then ()
  else
    Alice_error.panic
      [ Pp.textf "Hash mismatch for file: %s" path
      ; Pp.newline
      ; Pp.textf "Expected hash: %s" (Sha256.to_hex expected_hash)
      ; Pp.newline
      ; Pp.textf "Actual hash: %s" (Sha256.to_hex actual_hash)
      ]
;;

module Remote_tarball = struct
  module Fetch = Alice_io.Fetch
  module Extract = Alice_io.Extract
  module Temp_dir = Alice_io.Temp_dir

  type t =
    { name : string
    ; url : Url.t
    ; top_level_dir : Filename.t
    ; sha256 : Sha256.t
    }

  let create ~name ~url ~top_level_dir ~sha256 = { name; url; top_level_dir; sha256 }

  let process { name; url; top_level_dir; sha256 } ~dest =
    Temp_dir.with_ ~prefix:"alice." ~suffix:".tools" ~f:(fun dir ->
      let tarball_file = Filename.concat dir (sprintf "%s.tar.gz" name) in
      Fetch.fetch ~url ~output_file:tarball_file;
      panic_if_hashes_don't_match tarball_file sha256;
      Extract.extract ~tarball_file ~output_dir:dir;
      print_endline (sprintf "x: %s" top_level_dir))
  ;;
end

module Remote_tarballs = struct
  type t =
    { compiler : Remote_tarball.t
    ; ocamllsp : Remote_tarball.t
    ; ocamlformat : Remote_tarball.t
    }

  let rt = Remote_tarball.create
  let all { compiler; ocamllsp; ocamlformat } = [ compiler; ocamllsp; ocamlformat ]

  (* Just hard-code these for now to keep things simple! *)
  let macos_aarch64_latest =
    { compiler =
        rt
          ~name:"ocaml"
          ~url:
            "https://s3.g.s4.mega.io/ycsnsngpe2elgjdd2uzbdpyj6s54q5itlvy6g/alice/compilers/ocaml-macos-aarch64.5.3.1%2Brelocatable.tar.gz"
          ~top_level_dir:"ocaml.5.3.1+relocatable"
          ~sha256:
            (Sha256.of_hex
               "3d88de1ecb28a2071c843a8faf6e8bbfa54ca704b7915b61f982d3286e59929d")
    ; ocamllsp =
        rt
          ~name:"ocamllsp"
          ~url:
            "https://s3.g.s4.mega.io/ycsnsngpe2elgjdd2uzbdpyj6s54q5itlvy6g/alice/tools/ocamllsp/ocamllsp-macos-aarch64.1.22.0-built-with-ocaml.5.3.1%2Brelocatable.tar.gz"
          ~top_level_dir:"ocamllsp.1.22.0-built-with-ocaml.5.3.1+relocatable"
          ~sha256:
            (Sha256.of_hex
               "6986bc8d8c8e0a10345faaa9ed198419a0e62845d03e68ce0bedf8465841a07d")
    ; ocamlformat =
        rt
          ~name:"ocamlformat"
          ~url:
            "http://localhost:8000/ocamlformat-macos-aarch64.0.27.0-built-with-ocaml.5.3.1+relocatable.tar.gz"
            (*"https://s3.g.s4.mega.io/ycsnsngpe2elgjdd2uzbdpyj6s54q5itlvy6g/alice/tools/ocamlformat/ocamlformat-macos-aarch64.0.27.0-built-with-ocaml.5.3.1%2Brelocatable.tar.gz"*)
          ~top_level_dir:"ocamlformat.0.27.0-built-with-ocaml.5.3.1+relocatable"
          ~sha256:
            (Sha256.of_hex
               "28821b4d1aada07e5f8cca47c27a2f238219b70ee898bf905e4d6e8cf14b5808")
    }
  ;;
end

let get =
  let open Arg_parser in
  let+ () = const () in
  Remote_tarball.process Remote_tarballs.macos_aarch64_latest.ocamlformat ~dest:"/tmp/x"
;;

let subcommand =
  let open Command in
  subcommand "tools" (group [ subcommand "get" (singleton get) ])
;;
