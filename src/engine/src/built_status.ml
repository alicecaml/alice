open! Alice_stdlib

type t =
  | Built
  | Reused

let is_built = function
  | Built -> true
  | Reused -> false
;;

let either_built a b =
  match a, b with
  | Reused, Reused -> Reused
  | _ -> Built
;;

let any_built ts =
  if
    List.exists ts ~f:(function
      | Built -> true
      | Reused -> false)
  then Built
  else Reused
;;
