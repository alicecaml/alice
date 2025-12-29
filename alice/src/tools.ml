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

  let dir { name; _ } installation = Alice_installation.roots installation / name

  let install t env installation ~target ~compiler_only ~global =
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
    | None -> install_to (dir t installation)
  ;;

  let make_current t installation os_type =
    let current_path = Alice_installation.current installation in
    if File_ops.exists current_path then File_ops.rm_rf current_path;
    let src = dir t installation in
    let dst = current_path in
    match Alice_env.Os_type.is_windows os_type with
    | true -> File_ops.cp_rf ~src ~dst
    | false -> File_ops.symlink ~src ~dst
  ;;

  let is_installed t installation = File_ops.exists (dir t installation)
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

  let update_path t installation ~root =
    let bin_dir =
      match root with
      | None -> Alice_installation.current_bin installation
      | Some root -> Root.dir root installation / Basename.of_filename "bin"
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
      ~doc:"Install tools to this directory rather than the default location."
  and+ target = Target.arg_parser in
  let env = Alice_env.current_env () in
  let os_type = Alice_env.Os_type.current () in
  let installation = Alice_installation.create os_type env in
  Root.install root env installation ~target ~compiler_only ~global;
  if not (Alice_io.File_ops.exists (Alice_installation.current installation))
  then (
    let open Alice_ui in
    println
      (raw_message
         (sprintf
            "No current root was found so making %s the current root."
            (Basename.to_filename root.name)));
    Root.make_current root installation os_type)
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
  let installation = Alice_installation.create os_type env in
  print_endline (Shell.update_path shell installation ~root)
;;

let change =
  let open Arg_parser in
  let+ () = Common.set_globals_from_flags
  and+ root = pos_req 0 Root.conv in
  let env = Alice_env.current_env () in
  let os_type = Alice_env.Os_type.current () in
  let installation = Alice_installation.create os_type env in
  if Root.is_installed root installation
  then Root.make_current root installation os_type
  else
    Alice_error.panic
      [ Pp.textf
          "Root %s is not installed. Run `alice tools get %s` first."
          (Basename.to_filename root.name)
          (Basename.to_filename root.name)
      ]
;;

module Lookup_prog = struct
  type t =
    { prog_path : Absolute_path.non_root_t option
    ; augmented_env : Env.t
    }

  let lookup_prog prog =
    let open Alice_env in
    let env = current_env () in
    let os_type = Os_type.current () in
    let path_variable = Path_variable.get_or_empty os_type env in
    let installation = Alice_installation.create os_type env in
    let augmented_path_variable =
      `Non_root (Alice_installation.current_bin installation) :: path_variable
    in
    let augmented_env = Path_variable.set augmented_path_variable os_type env in
    let prog_path = Alice_which.which os_type augmented_env prog in
    { prog_path; augmented_env }
  ;;
end

let which =
  let open Arg_parser in
  let+ () = Common.set_globals_from_flags
  and+ prog = pos_req 0 string ~value_name:"PROG" ~doc:"Program to look up." in
  match (Lookup_prog.lookup_prog prog).prog_path with
  | Some prog_path -> print_endline (Absolute_path.to_filename prog_path)
  | None -> Alice_error.user_exn [ Pp.textf "Can't find %S executable!" prog ]
;;

let exec =
  let open Arg_parser in
  let+ () = Common.set_globals_from_flags
  and+ prog = pos_req 0 string ~value_name:"PROG" ~doc:"Program to run."
  and+ args =
    pos_right 0 string ~value_name:"ARGS" ~doc:"Arguments to pass to program."
  in
  let { Lookup_prog.prog_path; augmented_env } = Lookup_prog.lookup_prog prog in
  let prog =
    (* Compute the absolute path to the exe if it can be found in the PATH
       variable (after augmenting the environment with some Alice-specific
       paths). This avoids relying on the machinery for spawning processes to
       respect the modified PATH variable, as this was found to be unreliable
       on Windows when running in CMD.exe. *)
    match prog_path with
    | Some prog_path -> Absolute_path.to_filename prog_path
    | None -> prog
  in
  let open Alice_ui in
  match Alice_io.Process.Blocking.run ~env:augmented_env prog ~args with
  | Error `Prog_not_available ->
    Alice_error.panic [ Pp.textf "The executable %s does not exist." prog ]
  | Ok { status = Exited code; _ } -> exit code
  | Ok { status = Signaled signal | Stopped signal; _ } ->
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
           "which"
           (singleton
              which
              ~doc:"Print the path to an exe in the env used by the exec command.")
       ; subcommand
           "exec"
           (singleton
              exec
              ~doc:"Run a command in an environment with access to the tools.")
       ])
;;
