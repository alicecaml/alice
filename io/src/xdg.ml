include Alice_stdlib.Xdg

let create () = create ~win32:Sys.win32 ~env:Sys.getenv_opt ()
