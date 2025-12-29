open! Alice_stdlib
open Alice_hierarchy
open Alice_io

module Remote_tarball = struct
  type t =
    { name : string
    ; version : string
    ; url_base : string
    ; url_file : string
    ; top_level_dir : Basename.t
    ; sha256 : Sha256.t
    }

  let create ~name ~version ~url_base ~url_file ~top_level_dir ~sha256 =
    { name
    ; version
    ; url_base
    ; url_file
    ; top_level_dir = Basename.of_filename top_level_dir
    ; sha256 = Sha256.of_hex sha256
    }
  ;;

  let panic_if_hashes_don't_match path expected_hash =
    let actual_hash = Sha256.file (Absolute_path.to_filename path) in
    if Sha256.equal actual_hash expected_hash
    then ()
    else
      Alice_error.panic
        [ Pp.textf "Hash mismatch for file: %s" (Absolute_path.to_filename path)
        ; Pp.newline
        ; Pp.textf "Expected hash: %s" (Sha256.to_hex expected_hash)
        ; Pp.newline
        ; Pp.textf "Actual hash: %s" (Sha256.to_hex actual_hash)
        ]
  ;;

  let install { name; version; url_base; url_file; top_level_dir; sha256 } env ~dst =
    let url = String.cat url_base url_file in
    let open Alice_ui in
    Temp_dir.with_ ~prefix:"alice." ~suffix:".tools" ~f:(fun dir ->
      let tarball_file = dir / Basename.of_filename (sprintf "%s.tar.gz" name) in
      println (verb_message `Fetching (sprintf "%s.%s (%s)..." name version url_file));
      Fetch.fetch env ~url ~output_file:tarball_file;
      panic_if_hashes_don't_match tarball_file sha256;
      println (verb_message `Unpacking (sprintf "%s.%s..." name version));
      Extract.extract env ~tarball_file ~output_dir:dir;
      File_ops.recursive_move_between_dirs ~src:(dir / top_level_dir) ~dst;
      print_newline ();
      println
        (raw_message
           ~style:Styles.success
           (sprintf
              "Successfully installed %s.%s to '%s'!\n"
              name
              version
              (Absolute_path.to_filename dst))))
  ;;
end

type t =
  { compiler : Remote_tarball.t
  ; ocamllsp : Remote_tarball.t
  ; ocamlformat : Remote_tarball.t
  ; dot_merlin_reader : Remote_tarball.t
  }

let rt = Remote_tarball.create

let all { compiler; ocamllsp; ocamlformat; dot_merlin_reader } =
  [ compiler; ocamllsp; ocamlformat; dot_merlin_reader ]
;;

let make compiler ocamllsp ocamlformat dot_merlin_reader =
  { compiler; ocamllsp; ocamlformat; dot_merlin_reader }
;;

let url_base_5_3_1 =
  "https://github.com/alicecaml/alice-tools/releases/download/5.3.1+relocatable/"
;;

(* Just hard-code these for now to keep things simple! *)

module Root_5_3_1 = struct
  let compiler plat_string sha256 =
    rt
      ~name:"ocaml"
      ~version:"5.3.1+relocatable"
      ~url_base:url_base_5_3_1
      ~url_file:(sprintf "ocaml-5.3.1+relocatable-%s.tar.gz" plat_string)
      ~top_level_dir:(sprintf "ocaml-5.3.1+relocatable-%s" plat_string)
      ~sha256
  ;;

  let ocamllsp plat_string sha256 =
    rt
      ~name:"ocamllsp"
      ~version:"1.22.0"
      ~url_base:url_base_5_3_1
      ~url_file:
        (sprintf
           "ocamllsp-1.22.0-built-with-ocaml-5.3.1+relocatable-%s.tar.gz"
           plat_string)
      ~top_level_dir:
        (sprintf "ocamllsp-1.22.0-built-with-ocaml-5.3.1+relocatable-%s" plat_string)
      ~sha256
  ;;

  let ocamlformat plat_string sha256 =
    rt
      ~name:"ocamlformat"
      ~version:"0.27.0"
      ~url_base:url_base_5_3_1
      ~url_file:
        (sprintf
           "ocamlformat-0.27.0-built-with-ocaml-5.3.1+relocatable-%s.tar.gz"
           plat_string)
      ~top_level_dir:
        (sprintf "ocamlformat-0.27.0-built-with-ocaml-5.3.1+relocatable-%s" plat_string)
      ~sha256
  ;;

  let dot_merlin_reader plat_string sha256 =
    rt
      ~name:"dot-merlin-reader"
      ~version:"5.4.1-503"
      ~url_base:url_base_5_3_1
      ~url_file:
        (sprintf
           "dot-merlin-reader-5.4.1-503-built-with-ocaml-5.3.1+relocatable-%s.tar.gz"
           plat_string)
      ~top_level_dir:
        (sprintf
           "dot-merlin-reader-5.4.1-503-built-with-ocaml-5.3.1+relocatable-%s"
           plat_string)
      ~sha256
  ;;

  let aarch64_linux_musl_static_5_3_1 =
    let plat_string = "aarch64-linux-musl-static" in
    make
      (compiler
         plat_string
         "661463be46580dd00285bef75b4d6311f2095c7deae8584667f9d76ed869276e")
      (ocamllsp
         plat_string
         "522880c7800230d62b89820419ec21e364f72d54ed560eb0920d55338438cacf")
      (ocamlformat
         plat_string
         "3cba0bfa0f075f3ab4f01752d18dd5dbbec03e50153892fdb83bc6b55b8e5f0e")
      (dot_merlin_reader
         plat_string
         "8a0e3366254b0c54324bc66e7063aac121283deae78ae2180f92d1b559f9dcfe")
  ;;

  let aarch64_linux_gnu_5_3_1 =
    let plat_string = "aarch64-linux-gnu" in
    make
      (compiler
         plat_string
         "c89f1fc2a34222a95984a05e823a032f5c5e7d6917444685d88e837b6744491a")
      (ocamllsp
         plat_string
         "05ee153f176fbf077166fe637136fc679edd64a0942b8a74e8ac77878ac25d3f")
      (ocamlformat
         plat_string
         "28bceaceeb6055fada11cf3ba1dcc3ffec4997925dee096a736fdaef4d370e56")
      (dot_merlin_reader
         plat_string
         "246a162eb7d288cf39a8e1fb0809d2cddbe86185ab4e757b2a017f66e00d7df3")
  ;;

  let aarch64_macos_5_3_1 =
    let plat_string = "aarch64-macos" in
    make
      (compiler
         plat_string
         "4e9b683dc39867dcd5452e25a154c2964cd02a992ca4d3da33a46a24b6cb2187")
      (ocamllsp
         plat_string
         "bbfcd59f655dd96eebfa3864f37fea3d751d557b7773a5445e6f75891bc03cd3")
      (ocamlformat
         plat_string
         "555d460f1b9577fd74a361eb5675f840ad2a73a4237fb310b8d6bc169c0df90c")
      (dot_merlin_reader
         plat_string
         "96a549fa9c3a30ba3d36463f3808f2e3f943cb3f3f469fee8277686256be2a6c")
  ;;

  let x86_64_linux_musl_static_5_3_1 =
    let plat_string = "x86_64-linux-musl-static" in
    make
      (compiler
         plat_string
         "bc00d5cccc68cc1b4e7058ec53ad0f00846ecd1b1fb4a7b62e45b1b2b0dc9cb5")
      (ocamllsp
         plat_string
         "a630fe7ce411fae60683ca30066c9d6bc28add4c0053191381745b36e3ccd2db")
      (ocamlformat
         plat_string
         "440718b9272f17a08f1b7d5a620400acb76d37e82cfc609880ce4d7253fc8d9e")
      (dot_merlin_reader
         plat_string
         "68c3fb4d3973bea0567c16b66575d19b1aa0885fa53f7573eef0612ff650c077")
  ;;

  let x86_64_linux_gnu_5_3_1 =
    let plat_string = "x86_64-linux-gnu" in
    make
      (compiler
         plat_string
         "3a7d69e8a8650f4527382081f0cfece9edf7ae7e12f3eb38fbb3880549b2ca90")
      (ocamllsp
         plat_string
         "0a7afeec4d7abf0e4c701ab75076a5ede2d25164260157e70970db4c4592ffab")
      (ocamlformat
         plat_string
         "05ff3630ff2bed609ba062e85ecfdce0cf905124887cfb8b2544e489d0cbaf53")
      (dot_merlin_reader
         plat_string
         "3054df1870dd168c11ffda3d55883b828981cf5437b7b3000e37cce2d8fbfbb2")
  ;;

  let x86_64_macos_5_3_1 =
    let plat_string = "x86_64-macos" in
    make
      (compiler
         plat_string
         "7d09047e53675cedddef604936d304807cfbe0052e4c4b56a2c7c05ac0c83304")
      (ocamllsp
         plat_string
         "f5483730fcf29acfdf98a99c561306fd95f8aebaac76a474c418365766365fc4")
      (ocamlformat
         plat_string
         "c3cdc14d1666e37197c5ff2e8a0a416b765b96b10aabe6b80b5aa3cf6b780339")
      (dot_merlin_reader
         plat_string
         "6e4e950b521ccbc5d4fe850ff5782058a38e653fa511ac03dadede54c2f89fa0")
  ;;

  let x86_64_windows_5_3_1 =
    let plat_string = "x86_64-windows" in
    make
      (compiler
         plat_string
         "ed4256fa9aeb8ecaa846a58ee70d97d0519ec2878b5c5e2e0895e52a1796198e")
      (ocamllsp
         plat_string
         "fcce194c359656b0e507f252877f5874e5d0c598711b3079e2b8938991b714fe")
      (ocamlformat
         plat_string
         "26b385b694cc1c03595ad91baac663a37f1e86faf57848d06e1d2dbc63bfefaf")
      (dot_merlin_reader
         plat_string
         "e8666cf4b40452775511ac130781c7a492477ce56e16536288b3b9170d208cf9")
  ;;
end

let install_all t env ~dst =
  List.iter (all t) ~f:(fun rt -> Remote_tarball.install rt env ~dst)
;;

let install_compiler { compiler; _ } env ~dst = Remote_tarball.install compiler env ~dst
