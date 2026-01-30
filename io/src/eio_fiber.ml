open! Alice_stdlib
include Eio.Fiber

let rec all_values fs =
  match fs with
  | [] -> []
  | [ x ] -> [ x () ]
  | [ a; b ] ->
    let a, b = pair a b in
    [ a; b ]
  | x :: xs ->
    let x, xs = pair x (fun () -> all_values xs) in
    x :: xs
;;
