open! Alice_stdlib
open Alice_hierarchy
open Climate

module Root = struct
  open Alice_io
  open Remote_tarballs.Root_5_3_1

  type t =
    { name : Basename.t
    ; remote_tarballs_by_target : Remote_tarballs.t Target.Map.t
    }

  let root_5_3_1 =
    { name = Basename.of_filename "5.3.1+relocatable"
    ; remote_tarballs_by_target =
        Target.Map.of_list_exn
          [ ( Target.create ~os:Linux ~arch:Aarch64 ~linked:Static
            , aarch64_linux_musl_static_5_3_1 )
          ; Target.create ~os:Linux ~arch:Aarch64 ~linked:Dynamic, aarch64_linux_gnu_5_3_1
          ; Target.create ~os:Macos ~arch:Aarch64 ~linked:Dynamic, aarch64_macos_5_3_1
          ; ( Target.create ~os:Linux ~arch:X86_64 ~linked:Static
            , x86_64_linux_musl_static_5_3_1 )
          ; Target.create ~os:Linux ~arch:X86_64 ~linked:Dynamic, x86_64_linux_gnu_5_3_1
          ; Target.create ~os:Macos ~arch:X86_64 ~linked:Dynamic, x86_64_macos_5_3_1
          ; Target.create ~os:Windows ~arch:X86_64 ~linked:Dynamic, x86_64_windows_5_3_1
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
      then Remote_tarballs.install_compiler remote_tarballs env ~dst
      else Remote_tarballs.install_all remote_tarballs env ~dst
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
  let env = Alice_env.current_env () in
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
  let env = Alice_env.current_env () in
  let os_type = Alice_env.Os_type.current () in
  let install_dir = Alice_install_dir.create os_type env in
  print_endline (Shell.update_path shell install_dir ~root)
;;

let change =
  let open Arg_parser in
  let+ () = Common.set_globals_from_flags
  and+ root = pos_req 0 Root.conv in
  let env = Alice_env.current_env () in
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
  let env = Alice_env.current_env () in
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
       ; subcommand "change" (singleton change ~doc:"Change the currently active root.")
       ; subcommand
           "exec"
           (singleton
              exec
              ~doc:"Run a command in an environment with access to the tools.")
       ])
;;
