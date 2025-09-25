open! Alice_stdlib
open Alice_hierarchy

let xdg () = Alice_io.Xdg.create ()

let base_dir_lazy =
  lazy (Path.concat (Xdg.home_dir (xdg ()) |> Path.absolute) (Path.relative ".alice"))
;;

let base_dir () = Lazy.force base_dir_lazy
let roots_dir () = Path.concat (base_dir ()) (Path.relative "roots")
let current () = Path.concat (base_dir ()) (Path.relative "current")
let current_bin () = Path.concat (current ()) (Path.relative "bin")
let completions_dir () = Path.concat (base_dir ()) (Path.relative "completions")
let env_dir () = Path.concat (base_dir ()) (Path.relative "env")
