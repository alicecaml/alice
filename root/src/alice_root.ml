open! Alice_stdlib
open Alice_hierarchy

let xdg () = Alice_io.Xdg.create ()

let base_dir_lazy =
  lazy
    ((Xdg.home_dir (xdg ()) |> Absolute_path.of_filename_assert_non_root)
     / Basename.of_filename ".alice")
;;

let base_dir () = Lazy.force base_dir_lazy
let roots_dir () = base_dir () / Basename.of_filename "roots"
let current () = base_dir () / Basename.of_filename "current"
let current_bin () = current () / Basename.of_filename "bin"
let completions_dir () = base_dir () / Basename.of_filename "completions"
let env_dir () = base_dir () / Basename.of_filename "env"
