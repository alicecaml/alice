include Stdlib.ListLabels

let filter_opt t = filter_map ~f:Fun.id t

let rec last = function
  | [] -> None
  | [ x ] -> Some x
  | _ :: xs -> last xs
;;

let rec split_last = function
  | [] -> None
  | [ x ] -> Some ([], x)
  | _ :: xs -> split_last xs
;;

let all t = for_all t ~f:Fun.id
let any t = exists t ~f:Fun.id
