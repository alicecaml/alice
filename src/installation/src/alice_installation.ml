open! Alice_stdlib
open Alice_hierarchy

type t = { xdg : Xdg.t }

let create os_type env = { xdg = Alice_env.Xdg.create os_type env }
let home { xdg } = Xdg.home_dir xdg |> Absolute_path.of_filename_assert_non_root
let data { xdg } = Xdg.data_dir xdg |> Absolute_path.of_filename_assert_non_root
let local_bin t = home t / Basename.of_filename ".local" / Basename.of_filename "bin"

let bash_completion_script_path t =
  data t
  / Basename.of_filename "bash-completions"
  / Basename.of_filename "completions"
  / Basename.of_filename "alice"
;;

let alice_data t = data t / Basename.of_filename "alice"
let roots t = alice_data t / Basename.of_filename "roots"
let current t = alice_data t / Basename.of_filename "current"
let current_bin t = current t / Basename.of_filename "bin"
let env t = alice_data t / Basename.of_filename "env"
