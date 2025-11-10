open! Alice_stdlib

type t =
  { optimization_level : [ `O2 | `O3 ] option
  ; debug : bool
  ; name : string
  }

let debug = { optimization_level = None; debug = true; name = "debug" }
let release = { optimization_level = Some `O2; debug = false; name = "release" }
let name { name; _ } = name

let ocaml_compiler_command t ocaml_compiler ~args =
  let prog = Alice_which.Ocaml_compiler.filename ocaml_compiler in
  let env = Alice_which.Ocaml_compiler.env ocaml_compiler in
  let args =
    (if t.debug then [ "-g" ] else [])
    @ (match t.optimization_level with
       | None -> []
       | Some `O2 -> [ "-O2" ]
       | Some `O3 -> [ "-O3" ])
    @ args
  in
  Command.create prog ~args env
;;
