open! Alice_stdlib
open Alice_hierarchy
open Climate

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

module Remote_tarball = struct
  open Alice_io

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

  let get { name; version; url_base; url_file; top_level_dir; sha256 } env ~dst =
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

module Remote_tarballs = struct
  type t =
    { compiler : Remote_tarball.t
    ; ocamllsp : Remote_tarball.t
    ; ocamlformat : Remote_tarball.t
    }

  let rt = Remote_tarball.create
  let all { compiler; ocamllsp; ocamlformat } = [ compiler; ocamllsp; ocamlformat ]

  let url_base_5_3_1 =
    "https://s3.g.s4.mega.io/ycsnsngpe2elgjdd2uzbdpyj6s54q5itlvy6g/alice/tools/5.3.1/"
  ;;

  (* Just hard-code these for now to keep things simple! *)

  let aarch64_linux_musl_static_5_3_1 =
    { compiler =
        rt
          ~name:"ocaml"
          ~version:"5.3.1+relocatable"
          ~url_base:url_base_5_3_1
          ~url_file:"ocaml-5.3.1+relocatable-aarch64-linux-musl-static.tar.gz"
          ~top_level_dir:"ocaml-5.3.1+relocatable-aarch64-linux-musl-static"
          ~sha256:"661463be46580dd00285bef75b4d6311f2095c7deae8584667f9d76ed869276e"
    ; ocamllsp =
        rt
          ~name:"ocamllsp"
          ~version:"1.22.0"
          ~url_base:url_base_5_3_1
          ~url_file:
            "ocamllsp-1.22.0-built-with-ocaml-5.3.1+relocatable-aarch64-linux-musl-static.tar.gz"
          ~top_level_dir:
            "ocamllsp-1.22.0-built-with-ocaml-5.3.1+relocatable-aarch64-linux-musl-static"
          ~sha256:"522880c7800230d62b89820419ec21e364f72d54ed560eb0920d55338438cacf"
    ; ocamlformat =
        rt
          ~name:"ocamlformat"
          ~version:"0.27.0"
          ~url_base:url_base_5_3_1
          ~url_file:
            "ocamlformat-0.27.0-built-with-ocaml-5.3.1+relocatable-aarch64-linux-musl-static.tar.gz"
          ~top_level_dir:
            "ocamlformat-0.27.0-built-with-ocaml-5.3.1+relocatable-aarch64-linux-musl-static"
          ~sha256:"3cba0bfa0f075f3ab4f01752d18dd5dbbec03e50153892fdb83bc6b55b8e5f0e"
    }
  ;;

  let aarch64_linux_gnu_5_3_1 =
    { compiler =
        rt
          ~name:"ocaml"
          ~version:"5.3.1+relocatable"
          ~url_base:url_base_5_3_1
          ~url_file:"ocaml-5.3.1+relocatable-aarch64-linux-gnu.tar.gz"
          ~top_level_dir:"ocaml-5.3.1+relocatable-aarch64-linux-gnu"
          ~sha256:"c89f1fc2a34222a95984a05e823a032f5c5e7d6917444685d88e837b6744491a"
    ; ocamllsp =
        rt
          ~name:"ocamllsp"
          ~version:"1.22.0"
          ~url_base:url_base_5_3_1
          ~url_file:
            "ocamllsp-1.22.0-built-with-ocaml-5.3.1+relocatable-aarch64-linux-gnu.tar.gz"
          ~top_level_dir:
            "ocamllsp-1.22.0-built-with-ocaml-5.3.1+relocatable-aarch64-linux-gnu"
          ~sha256:"05ee153f176fbf077166fe637136fc679edd64a0942b8a74e8ac77878ac25d3f"
    ; ocamlformat =
        rt
          ~name:"ocamlformat"
          ~version:"0.27.0"
          ~url_base:url_base_5_3_1
          ~url_file:
            "ocamlformat-0.27.0-built-with-ocaml-5.3.1+relocatable-aarch64-linux-gnu.tar.gz"
          ~top_level_dir:
            "ocamlformat-0.27.0-built-with-ocaml-5.3.1+relocatable-aarch64-linux-gnu"
          ~sha256:"28bceaceeb6055fada11cf3ba1dcc3ffec4997925dee096a736fdaef4d370e56"
    }
  ;;

  let aarch64_macos_5_3_1 =
    { compiler =
        rt
          ~name:"ocaml"
          ~version:"5.3.1+relocatable"
          ~url_base:url_base_5_3_1
          ~url_file:"ocaml-5.3.1+relocatable-aarch64-macos.tar.gz"
          ~top_level_dir:"ocaml-5.3.1+relocatable-aarch64-macos"
          ~sha256:"4e9b683dc39867dcd5452e25a154c2964cd02a992ca4d3da33a46a24b6cb2187"
    ; ocamllsp =
        rt
          ~name:"ocamllsp"
          ~version:"1.22.0"
          ~url_base:url_base_5_3_1
          ~url_file:
            "ocamllsp-1.22.0-built-with-ocaml-5.3.1+relocatable-aarch64-macos.tar.gz"
          ~top_level_dir:
            "ocamllsp-1.22.0-built-with-ocaml-5.3.1+relocatable-aarch64-macos"
          ~sha256:"bbfcd59f655dd96eebfa3864f37fea3d751d557b7773a5445e6f75891bc03cd3"
    ; ocamlformat =
        rt
          ~name:"ocamlformat"
          ~version:"0.27.0"
          ~url_base:url_base_5_3_1
          ~url_file:
            "ocamlformat-0.27.0-built-with-ocaml-5.3.1+relocatable-aarch64-macos.tar.gz"
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
          ~url_base:url_base_5_3_1
          ~url_file:"ocaml-5.3.1+relocatable-x86_64-linux-musl-static.tar.gz"
          ~top_level_dir:"ocaml-5.3.1+relocatable-x86_64-linux-musl-static"
          ~sha256:"bc00d5cccc68cc1b4e7058ec53ad0f00846ecd1b1fb4a7b62e45b1b2b0dc9cb5"
    ; ocamllsp =
        rt
          ~name:"ocamllsp"
          ~version:"1.22.0"
          ~url_base:url_base_5_3_1
          ~url_file:
            "ocamllsp-1.22.0-built-with-ocaml-5.3.1+relocatable-x86_64-linux-musl-static.tar.gz"
          ~top_level_dir:
            "ocamllsp-1.22.0-built-with-ocaml-5.3.1+relocatable-x86_64-linux-musl-static"
          ~sha256:"a630fe7ce411fae60683ca30066c9d6bc28add4c0053191381745b36e3ccd2db"
    ; ocamlformat =
        rt
          ~name:"ocamlformat"
          ~version:"0.27.0"
          ~url_base:url_base_5_3_1
          ~url_file:
            "ocamlformat-0.27.0-built-with-ocaml-5.3.1+relocatable-x86_64-linux-musl-static.tar.gz"
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
          ~url_base:url_base_5_3_1
          ~url_file:"ocaml-5.3.1+relocatable-x86_64-linux-gnu.tar.gz"
          ~top_level_dir:"ocaml-5.3.1+relocatable-x86_64-linux-gnu"
          ~sha256:"3a7d69e8a8650f4527382081f0cfece9edf7ae7e12f3eb38fbb3880549b2ca90"
    ; ocamllsp =
        rt
          ~name:"ocamllsp"
          ~version:"1.22.0"
          ~url_base:url_base_5_3_1
          ~url_file:
            "ocamllsp-1.22.0-built-with-ocaml-5.3.1+relocatable-x86_64-linux-gnu.tar.gz"
          ~top_level_dir:
            "ocamllsp-1.22.0-built-with-ocaml-5.3.1+relocatable-x86_64-linux-gnu"
          ~sha256:"0a7afeec4d7abf0e4c701ab75076a5ede2d25164260157e70970db4c4592ffab"
    ; ocamlformat =
        rt
          ~name:"ocamlformat"
          ~version:"0.27.0"
          ~url_base:url_base_5_3_1
          ~url_file:
            "ocamlformat-0.27.0-built-with-ocaml-5.3.1+relocatable-x86_64-linux-gnu.tar.gz"
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
          ~url_base:url_base_5_3_1
          ~url_file:"ocaml-5.3.1+relocatable-x86_64-macos.tar.gz"
          ~top_level_dir:"ocaml-5.3.1+relocatable-x86_64-macos"
          ~sha256:"7d09047e53675cedddef604936d304807cfbe0052e4c4b56a2c7c05ac0c83304"
    ; ocamllsp =
        rt
          ~name:"ocamllsp"
          ~version:"1.22.0"
          ~url_base:url_base_5_3_1
          ~url_file:
            "ocamllsp-1.22.0-built-with-ocaml-5.3.1+relocatable-x86_64-macos.tar.gz"
          ~top_level_dir:"ocamllsp-1.22.0-built-with-ocaml-5.3.1+relocatable-x86_64-macos"
          ~sha256:"f5483730fcf29acfdf98a99c561306fd95f8aebaac76a474c418365766365fc4"
    ; ocamlformat =
        rt
          ~name:"ocamlformat"
          ~version:"0.27.0"
          ~url_base:url_base_5_3_1
          ~url_file:
            "ocamlformat-0.27.0-built-with-ocaml-5.3.1+relocatable-x86_64-macos.tar.gz"
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
          ~url_base:url_base_5_3_1
          ~url_file:"ocaml-5.3.1+relocatable-x86_64-windows.tar.gz"
          ~top_level_dir:"ocaml-5.3.1+relocatable-x86_64-windows"
          ~sha256:"ed4256fa9aeb8ecaa846a58ee70d97d0519ec2878b5c5e2e0895e52a1796198e"
    ; ocamllsp =
        rt
          ~name:"ocamllsp"
          ~version:"1.22.0"
          ~url_base:url_base_5_3_1
          ~url_file:
            "ocamllsp-1.22.0-built-with-ocaml-5.3.1+relocatable-x86_64-windows.tar.gz"
          ~top_level_dir:
            "ocamllsp-1.22.0-built-with-ocaml-5.3.1+relocatable-x86_64-windows"
          ~sha256:"fcce194c359656b0e507f252877f5874e5d0c598711b3079e2b8938991b714fe"
    ; ocamlformat =
        rt
          ~name:"ocamlformat"
          ~version:"0.27.0"
          ~url_base:url_base_5_3_1
          ~url_file:
            "ocamlformat-0.27.0-built-with-ocaml-5.3.1+relocatable-x86_64-windows.tar.gz"
          ~top_level_dir:
            "ocamlformat-0.27.0-built-with-ocaml-5.3.1+relocatable-x86_64-windows"
          ~sha256:"26b385b694cc1c03595ad91baac663a37f1e86faf57848d06e1d2dbc63bfefaf"
    }
  ;;

  let get_all t env ~dst = List.iter (all t) ~f:(fun rt -> Remote_tarball.get rt env ~dst)
  let get_compiler { compiler; _ } env ~dst = Remote_tarball.get compiler env ~dst
end

module Root = struct
  open Alice_io

  type t =
    { name : Basename.t
    ; remote_tarballs_by_target : Remote_tarballs.t Target.Map.t
    }

  let root_5_3_1 =
    { name = Basename.of_filename "5.3.1+relocatable"
    ; remote_tarballs_by_target =
        Target.Map.of_list_exn
          [ ( Target.create ~os:Linux ~arch:Aarch64 ~linked:Static
            , Remote_tarballs.aarch64_linux_musl_static_5_3_1 )
          ; ( Target.create ~os:Linux ~arch:Aarch64 ~linked:Dynamic
            , Remote_tarballs.aarch64_linux_gnu_5_3_1 )
          ; ( Target.create ~os:Macos ~arch:Aarch64 ~linked:Dynamic
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
    match Target.Map.find_opt target t.remote_tarballs_by_target with
    | Some x -> x
    | None ->
      Alice_error.user_exn
        [ Pp.textf
            "Root %s is not available for platform %s-%s (%sally linked)"
            (Basename.to_filename t.name)
            (Target.Os.to_string target.os)
            (Target.Arch.to_string target.arch)
            (Target.Linked.to_string target.linked)
        ]
  ;;

  let dir { name; _ } install_dir = Alice_install_dir.roots_dir install_dir / name

  let install t env install_dir ~target ~compiler_only ~global =
    let install_to dst =
      Alice_io.File_ops.mkdir_p dst;
      let remote_tarballs = choose_remote_tarballs t ~target in
      if compiler_only
      then Remote_tarballs.get_compiler remote_tarballs env ~dst
      else Remote_tarballs.get_all remote_tarballs env ~dst
    in
    match (global : Absolute_path.Root_or_non_root.t option) with
    | Some (`Non_root dst) -> install_to dst
    | Some (`Root dst) -> install_to dst
    | None -> install_to (dir t install_dir)
  ;;

  let make_current t install_dir os_type =
    let current_path = Alice_install_dir.current install_dir in
    if File_ops.exists current_path then File_ops.rm_rf current_path;
    let src = dir t install_dir in
    let dst = current_path in
    match Alice_env.Os_type.is_windows os_type with
    | true -> File_ops.cp_rf ~src ~dst
    | false -> File_ops.symlink ~src ~dst
  ;;

  let is_installed t install_dir = File_ops.exists (dir t install_dir)
  let latest = root_5_3_1

  let conv =
    let open Arg_parser in
    enum
      ~eq:(fun a b -> Basename.equal a.name b.name)
      ~default_value_name:"ROOT"
      [ Basename.to_filename root_5_3_1.name, root_5_3_1 ]
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

  let update_path t install_dir ~root =
    let bin_dir =
      match root with
      | None -> Alice_install_dir.current_bin install_dir
      | Some root -> Root.dir root install_dir / Basename.of_filename "bin"
    in
    match t with
    | Bash | Zsh -> sprintf "export PATH=\"%s:$PATH\"" (Absolute_path.to_filename bin_dir)
    | Fish ->
      sprintf "fish_add_path --prepend --path \"%s\"" (Absolute_path.to_filename bin_dir)
  ;;
end

let install =
  let open Arg_parser in
  let+ () = Common.set_globals_from_flags
  and+ root =
    let default = Root.latest in
    named_with_default
      [ "r"; "root" ]
      Root.conv
      ~default
      ~doc:
        (sprintf "Version to install. [default = %s]" (Basename.to_filename default.name))
  and+ compiler_only =
    flag [ "c"; "compiler-only" ] ~doc:"Only install the OCaml compiler."
  and+ global =
    Common.parse_absolute_path
      [ "g"; "global" ]
      ~doc:"Install tools to this directory rather than '~/.alice'."
  and+ target = Target.arg_parser in
  let env = Alice_env.Env.current () in
  let os_type = Alice_env.Os_type.current () in
  let install_dir = Alice_install_dir.create os_type env in
  Root.install root env install_dir ~target ~compiler_only ~global;
  if not (Alice_io.File_ops.exists (Alice_install_dir.current install_dir))
  then (
    let open Alice_ui in
    println
      (raw_message
         (sprintf
            "No current root was found so making %s the current root."
            (Basename.to_filename root.name)));
    Root.make_current root install_dir os_type)
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
    | None -> Bash
  in
  let env = Alice_env.Env.current () in
  let os_type = Alice_env.Os_type.current () in
  let install_dir = Alice_install_dir.create os_type env in
  print_endline (Shell.update_path shell install_dir ~root)
;;

let change =
  let open Arg_parser in
  let+ () = Common.set_globals_from_flags
  and+ root = pos_req 0 Root.conv in
  let env = Alice_env.Env.current () in
  let os_type = Alice_env.Os_type.current () in
  let install_dir = Alice_install_dir.create os_type env in
  if Root.is_installed root install_dir
  then Root.make_current root install_dir os_type
  else
    Alice_error.panic
      [ Pp.textf
          "Root %s is not installed. Run `alice tools get %s` first."
          (Basename.to_filename root.name)
          (Basename.to_filename root.name)
      ]
;;

let exec =
  let open Arg_parser in
  let+ () = Common.set_globals_from_flags
  and+ prog = pos_req 0 string ~value_name:"PROG" ~doc:"Program to run."
  and+ args =
    pos_right 0 string ~value_name:"ARGS" ~doc:"Arguments to pass to program."
  in
  let open Alice_ui in
  let open Alice_env in
  let env = Env.current () in
  let os_type = Os_type.current () in
  let path_variable = Path_variable.get_or_empty os_type env in
  let install_dir = Alice_install_dir.create os_type env in
  let augmented_path_variable =
    `Non_root (Alice_install_dir.current_bin install_dir) :: path_variable
  in
  let augmented_env = Path_variable.set augmented_path_variable os_type env in
  match Alice_io.Process.Blocking.run ~env:augmented_env prog ~args with
  | Error `Prog_not_available ->
    Alice_error.panic [ Pp.textf "The executable %s does not exist." prog ]
  | Ok (Exited code) -> exit code
  | Ok (Signaled signal | Stopped signal) ->
    println
      (raw_message
         (sprintf "The executable %s was stopped by a signal (%d)." prog signal));
    exit 0
;;

let subcommand =
  let open Command in
  subcommand
    "tools"
    (group
       ~doc:"Manage tools for building and developing OCaml projects."
       [ subcommand "install" (singleton install ~doc:"Install OCaml development tools.")
       ; subcommand
           "env"
           (singleton
              env
              ~doc:"Print a command which can be eval'd to add tools to PATH.")
       ; subcommand "change" (singleton change ~doc:"Change the currently active root")
       ; subcommand
           "exec"
           (singleton
              exec
              ~doc:"Run a command in an environment with access to the tools.")
       ])
;;
