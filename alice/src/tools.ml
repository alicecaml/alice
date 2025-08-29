open! Alice_stdlib
open Alice_hierarchy
open Climate

let panic_if_hashes_don't_match path expected_hash =
  let actual_hash = Sha256.file (Path.to_filename path) in
  if Sha256.equal actual_hash expected_hash
  then ()
  else
    Alice_error.panic
      [ Pp.textf "Hash mismatch for file: %s" (Path.to_filename path)
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
    ; version : string
    ; url : Url.t
    ; top_level_dir : Path.Relative.t
    ; sha256 : Sha256.t
    }

  let create ~name ~version ~url ~top_level_dir ~sha256 =
    { name
    ; version
    ; url
    ; top_level_dir = Path.relative top_level_dir
    ; sha256 = Sha256.of_hex sha256
    }
  ;;

  let get { name; version; url; top_level_dir; sha256 } ~dst =
    let open Alice_print.Ui in
    Temp_dir.with_ ~prefix:"alice." ~suffix:".tools" ~f:(fun dir ->
      let tarball_file = Path.concat dir (Path.relative (sprintf "%s.tar.gz" name)) in
      println (verb_message `Fetching (sprintf "%s.%s..." name version));
      Fetch.fetch ~url ~output_file:tarball_file;
      panic_if_hashes_don't_match tarball_file sha256;
      println (verb_message `Unpacking (sprintf "%s.%s..." name version));
      Extract.extract ~tarball_file ~output_dir:dir;
      File_ops.recursive_move_between_dirs ~src:(Path.concat dir top_level_dir) ~dst;
      print_newline ();
      println
        (raw_message
           ~style:Styles.success
           (sprintf "Successfully installed %s.%s!\n" name version)))
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

  let url_base =
    "https://s3.g.s4.mega.io/ycsnsngpe2elgjdd2uzbdpyj6s54q5itlvy6g/alice/tools/"
  ;;

  let mk_url rel = String.cat url_base rel

  (* Just hard-code these for now to keep things simple! *)
  let aarch64_macos_5_3_1 =
    { compiler =
        rt
          ~name:"ocaml"
          ~version:"5.3.1+relocatable"
          ~url:(mk_url "5.3.1/ocaml-5.3.1+relocatable-aarch64-macos.tar.gz")
          ~top_level_dir:"ocaml-5.3.1+relocatable-aarch64-macos"
          ~sha256:"4e9b683dc39867dcd5452e25a154c2964cd02a992ca4d3da33a46a24b6cb2187"
    ; ocamllsp =
        rt
          ~name:"ocamllsp"
          ~version:"1.22.0"
          ~url:
            (mk_url
               "5.3.1/ocamllsp-1.22.0-built-with-ocaml-5.3.1+relocatable-aarch64-macos.tar.gz")
          ~top_level_dir:
            "ocamllsp-1.22.0-built-with-ocaml-5.3.1+relocatable-aarch64-macos"
          ~sha256:"bbfcd59f655dd96eebfa3864f37fea3d751d557b7773a5445e6f75891bc03cd3"
    ; ocamlformat =
        rt
          ~name:"ocamlformat"
          ~version:"0.27.0"
          ~url:
            (mk_url
               "5.3.1/ocamlformat-0.27.0-built-with-ocaml-5.3.1+relocatable-aarch64-macos.tar.gz")
          ~top_level_dir:
            "ocamlformat-0.27.0-built-with-ocaml-5.3.1+relocatable-aarch64-macos"
          ~sha256:"555d460f1b9577fd74a361eb5675f840ad2a73a4237fb310b8d6bc169c0df90c"
    }
  ;;

  let x86_64_linux_musl_static_5_3_1 =
    { compiler =
        rt
          ~name:"ocaml"
          ~version:"5.3.1+relocatable"
          ~url:(mk_url "5.3.1/ocaml-5.3.1+relocatable-x86_64-linux-musl-static.tar.gz")
          ~top_level_dir:"ocaml-5.3.1+relocatable-x86_64-linux-musl-static"
          ~sha256:"bc00d5cccc68cc1b4e7058ec53ad0f00846ecd1b1fb4a7b62e45b1b2b0dc9cb5"
    ; ocamllsp =
        rt
          ~name:"ocamllsp"
          ~version:"1.22.0"
          ~url:
            (mk_url
               "5.3.1/ocamllsp-1.22.0-built-with-ocaml-5.3.1+relocatable-x86_64-linux-musl-static.tar.gz")
          ~top_level_dir:
            "ocamllsp-1.22.0-built-with-ocaml-5.3.1+relocatable-x86_64-linux-musl-static"
          ~sha256:"a630fe7ce411fae60683ca30066c9d6bc28add4c0053191381745b36e3ccd2db"
    ; ocamlformat =
        rt
          ~name:"ocamlformat"
          ~version:"0.27.0"
          ~url:
            (mk_url
               "5.3.1/ocamlformat-0.27.0-built-with-ocaml-5.3.1+relocatable-x86_64-linux-musl-static.tar.gz")
          ~top_level_dir:
            "ocamlformat-0.27.0-built-with-ocaml-5.3.1+relocatable-x86_64-linux-musl-static"
          ~sha256:"440718b9272f17a08f1b7d5a620400acb76d37e82cfc609880ce4d7253fc8d9e"
    }
  ;;

  let x86_64_linux_gnu_5_3_1 =
    { compiler =
        rt
          ~name:"ocaml"
          ~version:"5.3.1+relocatable"
          ~url:(mk_url "5.3.1/ocaml-5.3.1+relocatable-x86_64-linux-gnu.tar.gz")
          ~top_level_dir:"ocaml-5.3.1+relocatable-x86_64-linux-gnu"
          ~sha256:"3a7d69e8a8650f4527382081f0cfece9edf7ae7e12f3eb38fbb3880549b2ca90"
    ; ocamllsp =
        rt
          ~name:"ocamllsp"
          ~version:"1.22.0"
          ~url:
            (mk_url
               "5.3.1/ocamllsp-1.22.0-built-with-ocaml-5.3.1+relocatable-x86_64-linux-gnu.tar.gz")
          ~top_level_dir:
            "ocamllsp-1.22.0-built-with-ocaml-5.3.1+relocatable-x86_64-linux-gnu"
          ~sha256:"0a7afeec4d7abf0e4c701ab75076a5ede2d25164260157e70970db4c4592ffab"
    ; ocamlformat =
        rt
          ~name:"ocamlformat"
          ~version:"0.27.0"
          ~url:
            (mk_url
               "5.3.1/ocamlformat-0.27.0-built-with-ocaml-5.3.1+relocatable-x86_64-linux-gnu.tar.gz")
          ~top_level_dir:
            "ocamlformat-0.27.0-built-with-ocaml-5.3.1+relocatable-x86_64-linux-gnu"
          ~sha256:"05ff3630ff2bed609ba062e85ecfdce0cf905124887cfb8b2544e489d0cbaf53"
    }
  ;;

  let x86_64_macos_5_3_1 =
    { compiler =
        rt
          ~name:"ocaml"
          ~version:"5.3.1+relocatable"
          ~url:(mk_url "5.3.1/ocaml-5.3.1+relocatable-x86_64-macos.tar.gz")
          ~top_level_dir:"ocaml-5.3.1+relocatable-x86_64-macos"
          ~sha256:"7d09047e53675cedddef604936d304807cfbe0052e4c4b56a2c7c05ac0c83304"
    ; ocamllsp =
        rt
          ~name:"ocamllsp"
          ~version:"1.22.0"
          ~url:
            (mk_url
               "5.3.1/ocamllsp-1.22.0-built-with-ocaml-5.3.1+relocatable-x86_64-macos.tar.gz")
          ~top_level_dir:"ocamllsp-1.22.0-built-with-ocaml-5.3.1+relocatable-x86_64-macos"
          ~sha256:"f5483730fcf29acfdf98a99c561306fd95f8aebaac76a474c418365766365fc4"
    ; ocamlformat =
        rt
          ~name:"ocamlformat"
          ~version:"0.27.0"
          ~url:
            (mk_url
               "5.3.1/ocamlformat-0.27.0-built-with-ocaml-5.3.1+relocatable-x86_64-macos.tar.gz")
          ~top_level_dir:
            "ocamlformat-0.27.0-built-with-ocaml-5.3.1+relocatable-x86_64-macos"
          ~sha256:"c3cdc14d1666e37197c5ff2e8a0a416b765b96b10aabe6b80b5aa3cf6b780339"
    }
  ;;

  let x86_64_windows_5_3_1 =
    { compiler =
        rt
          ~name:"ocaml"
          ~version:"5.3.1+relocatable"
          ~url:(mk_url "5.3.1/ocaml-5.3.1+relocatable-x86_64-windows.tar.gz")
          ~top_level_dir:"ocaml-5.3.1+relocatable-x86_64-windows"
          ~sha256:"ed4256fa9aeb8ecaa846a58ee70d97d0519ec2878b5c5e2e0895e52a1796198e"
    ; ocamllsp =
        rt
          ~name:"ocamllsp"
          ~version:"1.22.0"
          ~url:
            (mk_url
               "5.3.1/ocamllsp-1.22.0-built-with-ocaml-5.3.1+relocatable-x86_64-windows.tar.gz")
          ~top_level_dir:
            "ocamllsp-1.22.0-built-with-ocaml-5.3.1+relocatable-x86_64-windows"
          ~sha256:"fcce194c359656b0e507f252877f5874e5d0c598711b3079e2b8938991b714fe"
    ; ocamlformat =
        rt
          ~name:"ocamlformat"
          ~version:"0.27.0"
          ~url:
            (mk_url
               "5.3.1/ocamlformat-0.27.0-built-with-ocaml-5.3.1+relocatable-x86_64-windows.tar.gz")
          ~top_level_dir:
            "ocamlformat-0.27.0-built-with-ocaml-5.3.1+relocatable-x86_64-windows"
          ~sha256:"26b385b694cc1c03595ad91baac663a37f1e86faf57848d06e1d2dbc63bfefaf"
    }
  ;;

  let get_all t ~dst = List.iter (all t) ~f:(fun rt -> Remote_tarball.get rt ~dst)
end

module Root = struct
  open Alice_io

  type t =
    { name : string
    ; remote_tarballs_by_target : Remote_tarballs.t Target.Map.t
    }

  let root_5_3_1 =
    { name = "5.3.1+relocatable"
    ; remote_tarballs_by_target =
        Target.Map.of_list_exn
          [ ( Target.create ~os:Macos ~arch:Aarch64 ~linked:Dynamic
            , Remote_tarballs.aarch64_macos_5_3_1 )
          ; ( Target.create ~os:Linux ~arch:X86_64 ~linked:Static
            , Remote_tarballs.x86_64_linux_musl_static_5_3_1 )
          ; ( Target.create ~os:Linux ~arch:X86_64 ~linked:Dynamic
            , Remote_tarballs.x86_64_linux_gnu_5_3_1 )
          ; ( Target.create ~os:Macos ~arch:X86_64 ~linked:Dynamic
            , Remote_tarballs.x86_64_macos_5_3_1 )
          ; ( Target.create ~os:Windows ~arch:X86_64 ~linked:Dynamic
            , Remote_tarballs.x86_64_windows_5_3_1 )
          ]
    }
  ;;

  let choose_remote_tarballs t ~target =
    Target.Map.find target t.remote_tarballs_by_target
  ;;

  let dir { name; _ } = Path.concat (Alice_root.roots_dir ()) (Path.relative name)

  let get t =
    let target = Target.poll () in
    let remote_tarballs = choose_remote_tarballs t ~target in
    let dst = dir t in
    Alice_io.File_ops.mkdir_p dst;
    Remote_tarballs.get_all remote_tarballs ~dst
  ;;

  let make_current t =
    let current_path = Alice_root.current () in
    if File_ops.exists current_path then File_ops.rm_rf current_path;
    let src = dir t in
    let dst = current_path in
    match Sys.win32 with
    | true -> File_ops.cp_rf ~src ~dst
    | false -> File_ops.symlink ~src ~dst
  ;;

  let is_installed t = File_ops.exists (dir t)
  let latest = root_5_3_1

  let conv =
    let open Arg_parser in
    enum
      ~eq:(fun a b -> String.equal a.name b.name)
      ~default_value_name:"ROOT"
      [ root_5_3_1.name, root_5_3_1 ]
  ;;
end

module Shell = struct
  type t =
    | Bash
    | Zsh
    | Fish

  let equal a b =
    match a, b with
    | Bash, Bash | Zsh, Zsh | Fish, Fish -> true
    | _ -> false
  ;;

  let conv =
    let open Arg_parser in
    enum ~eq:equal ~default_value_name:"SHELL" [ "bash", Bash; "zsh", Zsh; "fish", Fish ]
  ;;

  let of_string_opt = function
    | "bash" -> Some Bash
    | "zsh" -> Some Zsh
    | "fish" -> Some Fish
    | _ -> None
  ;;

  let from_env () =
    match Alice_io.Env.shell () with
    | None -> Bash
    | Some shell_basename ->
      (match of_string_opt shell_basename with
       | Some shell -> shell
       | None ->
         Alice_error.panic
           [ Pp.textf "Don't know how to handle shell: %s" shell_basename ])
  ;;

  let update_path t ~root =
    let bin_dir =
      match root with
      | None -> Alice_root.current_bin ()
      | Some root -> Path.concat (Root.dir root) (Path.relative "bin")
    in
    match t with
    | Bash | Zsh -> sprintf "export PATH=\"%s:$PATH\"" (Path.to_filename bin_dir)
    | Fish -> sprintf "fish_add_path --prepend --path \"%s\"" (Path.to_filename bin_dir)
  ;;
end

let get =
  let open Arg_parser in
  let+ () = Common.set_globals_from_flags
  and+ root = named_with_default [ "r"; "root" ] Root.conv ~default:Root.latest in
  Root.get root;
  if not (Alice_io.File_ops.exists (Alice_root.current ()))
  then (
    let open Alice_print.Ui in
    println
      (raw_message
         (sprintf "No current root was found so making %s the current root." root.name));
    Root.make_current root)
;;

let env =
  let open Arg_parser in
  let+ () = Common.set_globals_from_flags
  and+ shell =
    named_opt
      [ "s"; "shell" ]
      Shell.conv
      ~doc:"Print the env in the syntax for this shell rather than the current shell."
  and+ root =
    named_opt [ "r"; "root" ] Root.conv ~doc:"Use this root rather than the current root."
  in
  let shell =
    match shell with
    | Some shell -> shell
    | None -> Shell.from_env ()
  in
  print_endline (Shell.update_path shell ~root)
;;

let change =
  let open Arg_parser in
  let+ () = Common.set_globals_from_flags
  and+ root = pos_req 0 Root.conv in
  if Root.is_installed root
  then Root.make_current root
  else
    Alice_error.panic
      [ Pp.textf
          "Root %s is not installed. Run `alice tools get %s` first."
          root.name
          root.name
      ]
;;

let subcommand =
  let open Command in
  subcommand
    "tools"
    (group
       ~doc:"Manage tools for building and developing OCaml projects."
       [ subcommand "get" (singleton get)
       ; subcommand "env" (singleton env)
       ; subcommand "change" (singleton change)
       ])
;;
