open! Alice_stdlib
open Alice_ocaml_toolchain

type t =
  { optimization_level : [ `O2 | `O3 ] option
  ; debug : bool
  ; name : string
  }

let debug = { optimization_level = None; debug = true; name = "debug" }
let release = { optimization_level = Some `O2; debug = false; name = "release" }
let name { name; _ } = name

let ocamlopt_command t ocaml_toolchain ~args =
  let prog = Ocaml_toolchain.ocamlopt ocaml_toolchain in
  let env = Ocaml_toolchain.env ocaml_toolchain in
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
