open! Alice_stdlib

let shell () = Sys.getenv_opt "SHELL" |> Option.map ~f:Filename.basename
