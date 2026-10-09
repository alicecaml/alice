open! Alice_stdlib
open Climate
open Alice_hierarchy
open Alice_ui

module Env_script = struct
  let posix_src installation =
    let local_bin =
      Alice_installation.local_bin installation |> Absolute_path.to_filename
    in
    let current_bin =
      Alice_installation.current_bin installation |> Absolute_path.to_filename
    in
    sprintf
      {|#!/bin/sh
# Add the directory containing the 'alice' executable to PATH.
case :"$PATH": in
  *:"%s":*)
    ;;
  *)
    export PATH="%s:$PATH"
    ;;
esac

# Add the directory containing the OCaml development tools to PATH.
case :"$PATH": in
  *:"%s":*)
    ;;
  *)
    export PATH="%s:$PATH"
    ;;
esac|}
      local_bin
      local_bin
      current_bin
      current_bin
  ;;

  let bash_src installation =
    let bash_completion =
      Alice_installation.bash_completion_script_path installation
      |> Absolute_path.to_filename
    in
    String.cat
      (posix_src installation)
      (sprintf
         {|

# Only load completions if the shell is interactive.
if [ -t 0 ] && [ -f "%s" ]; then
  # Load bash completions for Alice.
  . "%s"
fi|}
         bash_completion
         bash_completion)
  ;;

  let zsh_src installation =
    let bash_completion =
      Alice_installation.bash_completion_script_path installation
      |> Absolute_path.to_filename
    in
    String.cat
      (posix_src installation)
      (sprintf
         {|

# Only load completions if the shell is interactive.
if [ -t 0 ] && [ -f %s ]; then
  # Load bash completions for Alice.
  autoload -Uz compinit bashcompinit
  compinit
  bashcompinit
  . "%s"
fi|}
         bash_completion
         bash_completion)
  ;;

  let fish_src installation =
    let local_bin =
      Alice_installation.local_bin installation |> Absolute_path.to_filename
    in
    let current_bin =
      Alice_installation.current_bin installation |> Absolute_path.to_filename
    in
    sprintf
      {|#!/usr/bin/env fish
# Add the directory containing the 'alice' executable to PATH.
if ! contains "%s" $PATH; and [ -d "%s" ]
  fish_add_path --prepend --path "%s"
end

# Add the directory containing the OCaml development tools to PATH.
if ! contains "%s" $PATH; and [ -d "%s" ]
  fish_add_path --prepend --path "%s"
end|}
      local_bin
      local_bin
      local_bin
      current_bin
      current_bin
      current_bin
  ;;

  let make_all installation =
    let module File_ops = Alice_io.File_ops in
    File_ops.mkdir_p (Alice_installation.env installation);
    let make_env_file filename text =
      File_ops.write_text_file
        (Alice_installation.env installation / Basename.of_filename filename)
        text
    in
    make_env_file "env.bash" (bash_src installation);
    make_env_file "env.fish" (fish_src installation);
    make_env_file "env.sh" (posix_src installation);
    make_env_file "env.zsh" (zsh_src installation);
    println
      (raw_message
         (sprintf
            "Installed env scripts to '%s'."
            (Absolute_path.to_filename (Alice_installation.env installation))))
  ;;
end

let command_for_completion_script = ref None

module Completion_script = struct
  let command () =
    match !command_for_completion_script with
    | Some command -> command
    | None ->
      Alice_error.panic [ Pp.text "command_for_completion_script has not been set" ]
  ;;

  let bash_src () =
    let command = command () in
    Command.completion_script_bash
      ~program_name:(Program_name.Literal "alice")
      ~program_exe_for_reentrant_query:`Program_name
      ~global_symbol_prefix:(`Custom "__alice")
      ~command_hash_in_function_names:false
      command
  ;;

  let make_bash installation =
    let module File_ops = Alice_io.File_ops in
    File_ops.mkdir_p
      (Alice_installation.bash_completion_script_path installation
       |> Absolute_path.parent
       |> Absolute_path.Root_or_non_root.assert_non_root);
    let make_bash_completion_file text =
      File_ops.write_text_file
        (Alice_installation.bash_completion_script_path installation)
        text
    in
    make_bash_completion_file (bash_src ());
    println
      (raw_message
         (sprintf
            "Installed bash completion script to '%s'."
            (Absolute_path.to_filename
               (Alice_installation.bash_completion_script_path installation))))
  ;;
end

let setup =
  let open Arg_parser in
  let+ () = Common.set_globals_from_flags in
  let env = Alice_env.current_env () in
  let os_dir = Alice_env.Os_type.current () in
  let installation = Alice_installation.create os_dir env in
  Env_script.make_all installation;
  Completion_script.make_bash installation
;;

let subcommand =
  let open Command in
  subcommand
    "internal"
    (group
       ~doc:"Internal commands."
       [ subcommand
           "completions"
           (group
              ~doc:"Generate a completion script for Alice."
              [ subcommand "bash" print_completion_script_bash ])
       ; subcommand "setup" (singleton setup ~doc:"Install the env scripts for Alice.")
       ])
;;
