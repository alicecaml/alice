open! Alice_stdlib

type t =
  | Native
  | Bytecode

let equal a b =
  match a, b with
  | Native, Native | Bytecode, Bytecode -> true
  | _ -> false
;;

let compare a b =
  match a, b with
  | Native, Native -> 0
  | Native, _ -> 1
  | _, Native -> -1
  | Bytecode, Bytecode -> 0
;;

let to_dyn = function
  | Native -> Dyn.variant "Native" []
  | Bytecode -> Dyn.variant "Bytecode" []
;;

let name = function
  | Native -> "native"
  | Bytecode -> "bytecode"
;;

let ocaml_object_file_ext = function
  | Native -> ".cmx"
  | Bytecode -> ".cmo"
;;

let ocaml_archive_file_ext = function
  | Native -> ".cmxa"
  | Bytecode -> ".cma"
;;
