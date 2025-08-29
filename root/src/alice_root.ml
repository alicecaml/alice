open! Alice_stdlib
open Alice_hierarchy

let xdg () = Alice_io.Xdg.create ()

let base_dir =
  lazy (Path.concat (Xdg.home_dir (xdg ()) |> Path.absolute) (Path.relative ".alice"))
;;

let roots_dir () = Path.concat (Lazy.force base_dir) (Path.relative "roots")
let current () = Path.concat (Lazy.force base_dir) (Path.relative "current")
let current_bin () = Path.concat (current ()) (Path.relative "bin")
