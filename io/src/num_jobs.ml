open! Alice_stdlib

type t =
  | Limited of int
  | Unlimited

let limited n =
  if n < 1
  then
    Alice_error.user_exn
      [ Pp.textf "Jobs may only be limited to a positive integer (got %d)." n ]
  else Limited n
;;

let unlimited = Unlimited

