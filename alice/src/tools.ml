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
  open Alice_io

  type t =
    { name : string
    ; url : Url.t
    ; top_level_dir : Filename.t
    ; sha256 : Sha256.t
    }

  let create ~name ~url ~top_level_dir ~sha256 = { name; url; top_level_dir; sha256 }

  let get { name; url; top_level_dir; sha256 } ~dst =
    Temp_dir.with_ ~prefix:"alice." ~suffix:".tools" ~f:(fun dir ->
      let tarball_file = Filename.concat dir (sprintf "%s.tar.gz" name) in
      Fetch.fetch ~url ~output_file:tarball_file;
      panic_if_hashes_don't_match tarball_file sha256;
      Extract.extract ~tarball_file ~output_dir:dir;
      File_ops.recursive_move_between_dirs ~src:(Filename.concat dir top_level_dir) ~dst)
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
  let url_base = "https://s3.g.s4.mega.io/ycsnsngpe2elgjdd2uzbdpyj6s54q5itlvy6g/alice/"
  let url_base = "http://localhost:8000/"
  let mk_url rel = String.cat url_base rel

  (* Just hard-code these for now to keep things simple! *)
  let macos_aarch64_5_3_1 =
    { compiler =
        rt
          ~name:"ocaml"
          ~url:(mk_url "compilers/ocaml-macos-aarch64.5.3.1%2Brelocatable.tar.gz")
          ~top_level_dir:"ocaml.5.3.1+relocatable"
          ~sha256:
            (Sha256.of_hex
               "3d88de1ecb28a2071c843a8faf6e8bbfa54ca704b7915b61f982d3286e59929d")
    ; ocamllsp =
        rt
          ~name:"ocamllsp"
          ~url:
            (mk_url
               "tools/ocamllsp/ocamllsp-macos-aarch64.1.22.0-built-with-ocaml.5.3.1%2Brelocatable.tar.gz")
          ~top_level_dir:"ocamllsp.1.22.0-built-with-ocaml.5.3.1+relocatable"
          ~sha256:
            (Sha256.of_hex
               "7706597a5ca9800a68fcd464e86397f0f81a9fc53ee51ad1f546ed20f2730110")
    ; ocamlformat =
        rt
          ~name:"ocamlformat"
          ~url:
            (mk_url
               "tools/ocamlformat/ocamlformat-macos-aarch64.0.27.0-built-with-ocaml.5.3.1+relocatable.tar.gz")
          ~top_level_dir:"ocamlformat.0.27.0-built-with-ocaml.5.3.1+relocatable"
          ~sha256:
            (Sha256.of_hex
               "28821b4d1aada07e5f8cca47c27a2f238219b70ee898bf905e4d6e8cf14b5808")
    }
  ;;

  let get_all t ~dst = List.iter (all t) ~f:(fun rt -> Remote_tarball.get rt ~dst)
end

let xdg () = Alice_io.Xdg.create ()
let base_dir () = Filename.concat (Xdg.home_dir (xdg ())) ".alice"
let roots_dir () = Filename.concat (base_dir ()) "roots"
let current_path () = Filename.concat (base_dir ()) "current"

module Root = struct
  type t =
    { name : string
    ; remote_tarballs_by_target : Remote_tarballs.t Target.Map.t
    }

  let root_5_3_1 =
    { name = "5.3.1"
    ; remote_tarballs_by_target =
        Target.Map.of_list_exn
          [ ( Target.create ~os:Macos ~arch:Aarch64 ~linked:Dynamic
            , Remote_tarballs.macos_aarch64_5_3_1 )
          ]
    }
  ;;

  let choose_remote_tarballs t ~target =
    Target.Map.find_exn t.remote_tarballs_by_target target
  ;;

  let dir { name; _ } = Filename.concat (roots_dir ()) name

  let get t =
    let target = Target.poll () in
    let remote_tarballs = choose_remote_tarballs t ~target in
    let dst = dir t in
    Alice_io.File_ops.mkdir_p dst;
    Remote_tarballs.get_all remote_tarballs ~dst
  ;;

  let make_current t = Unix.link
end

let get =
  let open Arg_parser in
  let+ () = unit in
  Root.get Root.root_5_3_1
;;

let subcommand =
  let open Command in
  subcommand "tools" (group [ subcommand "get" (singleton get) ])
;;
