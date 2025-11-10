open! Alice_stdlib
open Climate
open Alice_hierarchy
open Alice_ui

module Env_script = struct
  let posix_src =
    {|#!/bin/sh
# Add the directory containing the 'alice' executable to PATH.
case :"$PATH": in
  *:"$HOME/.alice/alice/bin":*)
    ;;
  *)
    export PATH="$HOME/.alice/alice/bin:$PATH"
    ;;
esac

# Add the directory containing the OCaml development tools to PATH.
case :"$PATH": in
  *:"$HOME/.alice/current/bin":*)
    ;;
  *)
    export PATH="$HOME/.alice/current/bin:$PATH"
    ;;
esac|}
  ;;

  let bash_src =
    String.cat
      posix_src
      {|

# Only load completions if the shell is interactive.
if [ -t 0 ] && [ -f "$HOME/.alice/completions/bash.sh" ]; then
  # Load bash completions for Alice.
  . "$HOME/.alice/completions/bash.sh"
fi|}
  ;;

  let zsh_src =
    String.cat
      posix_src
      {|

# Only load completions if the shell is interactive.
if [ -t 0 ] && [ -f "$ROOT"/share/bash-completion/completions/dune ]; then
  # Load bash completions for Alice.
  autoload -Uz compinit bashcompinit
  compinit
  bashcompinit
  . "$HOME/.alice/completions/bash.sh"
fi|}
  ;;

  let fish_src =
    {|#!/usr/bin/env fish
# Add the directory containing the 'alice' executable to PATH.
if ! contains "$HOME/.alice/alice/bin" $PATH; and [ -d "$HOME/.alice/alice/bin" ]
  fish_add_path --prepend --path "$HOME/.alice/alice/bin"
end

# Add the directory containing the OCaml development tools to PATH.
if ! contains "$HOME/.alice/current/bin" $PATH; and [ -d "$HOME/.alice/current/bin" ]
  fish_add_path --prepend --path "$HOME/.alice/current/bin"
end|}
  ;;

  let make_all install_dir =
    let module File_ops = Alice_io.File_ops in
    File_ops.mkdir_p (Alice_install_dir.env_dir install_dir);
    let make_env_file filename text =
      File_ops.write_text_file
        (Alice_install_dir.env_dir install_dir / Basename.of_filename filename)
        text
    in
    make_env_file "env.bash" bash_src;
    make_env_file "env.fish" fish_src;
    make_env_file "env.sh" posix_src;
    make_env_file "env.zsh" zsh_src;
    println
      (raw_message
         (sprintf
            "Installed env scripts to '%s'."
            (Absolute_path.to_filename (Alice_install_dir.env_dir install_dir))))
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

  let make_all install_dir =
    let module File_ops = Alice_io.File_ops in
    File_ops.mkdir_p (Alice_install_dir.completions_dir install_dir);
    let make_completion_file filename text =
      File_ops.write_text_file
        (Alice_install_dir.completions_dir install_dir / Basename.of_filename filename)
        text
    in
    make_completion_file "bash.sh" (bash_src ());
    println
      (raw_message
         (sprintf
            "Installed completion scripts to '%s'."
            (Absolute_path.to_filename (Alice_install_dir.completions_dir install_dir))))
  ;;
end

let setup =
  let open Arg_parser in
  let+ () = Common.set_globals_from_flags in
  let env = Alice_env.current_env () in
  let os_dir = Alice_env.Os_type.current () in
  let install_dir = Alice_install_dir.create os_dir env in
  Env_script.make_all install_dir;
  Completion_script.make_all install_dir
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
