type 'a t = ( :: ) of ('a * 'a list)

let singleton x = [ x ]
let to_list (x :: xs) = List.(x :: xs)
let to_dyn f t = Dyn.list f (to_list t)
let append (x :: xs) (y :: ys) = x :: List.concat [ xs; [ y ]; ys ]
let cons x xs = x :: to_list xs

let rev (x :: xs) =
  match List.rev xs with
  | [] -> [ x ]
  | y :: ys -> append (y :: ys) [ x ]
;;
