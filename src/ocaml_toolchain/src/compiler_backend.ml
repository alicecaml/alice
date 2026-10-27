open! Alice_stdlib

type t =
  | Native
  | Bytecode

let equal a b =
  match a, b with
  | Native, Native | Bytecode, Bytecode -> true
  | _ -> false
;;

let name = function
  | Native -> "native"
  | Bytecode -> "bytecode"
;;

