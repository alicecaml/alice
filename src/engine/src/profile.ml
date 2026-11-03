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

let ocaml_compiler_args t backend =
  let debug = if t.debug then [ "-g" ] else [] in
  let optimization_level =
    match (backend : Compiler_backend.t) with
    | Bytecode -> []
    | Native ->
      (match t.optimization_level with
       | None -> []
       | Some `O2 -> [ "-O2" ]
       | Some `O3 -> [ "-O3" ])
  in
  debug @ optimization_level
;;
