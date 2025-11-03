open! Alice_stdlib
open Alice_hierarchy

type t = { xdg : Xdg.t }

let create os_type env = { xdg = Alice_env.Xdg.create os_type env }
let home_dir { xdg } = Xdg.home_dir xdg |> Absolute_path.of_filename_assert_non_root
let base_dir t = home_dir t / Basename.of_filename ".alice"
let roots_dir t = base_dir t / Basename.of_filename "roots"
let current t = base_dir t / Basename.of_filename "current"
let current_bin t = current t / Basename.of_filename "bin"
let completions_dir t = base_dir t / Basename.of_filename "completions"
let env_dir t = base_dir t / Basename.of_filename "env"
