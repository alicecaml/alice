type 'a t = ( :: ) of ('a * 'a list)

let singleton x = [ x ]

let of_list_opt = function
  | [] -> None
  | x :: xs -> Some (x :: xs)
;;

let to_list (x :: xs) = List.(x :: xs)
let to_dyn f t = Dyn.list f (to_list t)
let append (x :: xs) (y :: ys) = x :: List.concat [ xs; [ y ]; ys ]
let cons x xs = x :: to_list xs

let rev (x :: xs) =
  match List.rev xs with
  | [] -> [ x ]
  | y :: ys -> append (y :: ys) [ x ]
;;

let map t ~f =
  match List.map (to_list t) ~f with
  | [] -> failwith "unreachable"
  | x :: xs -> x :: xs
;;

let equal ~eq a b = List.equal ~eq (to_list a) (to_list b)
let last (x :: xs) = List.last xs |> Option.value ~default:x
let split_last (x :: xs) = List.split_last xs |> Option.value ~default:([], x)
