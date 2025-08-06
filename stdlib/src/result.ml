open! Stdlib
include Result

let map t ~f = map f t
let bind t ~f = bind t f

let both a b =
  match a with
  | Error e -> Error e
  | Ok a ->
    (match b with
     | Error e -> Error e
     | Ok b -> Ok (a, b))
;;

module O = struct
  let ( >>= ) t f = bind t ~f
  let ( >>| ) t f = map t ~f
  let ( let* ) = ( >>= )
  let ( let+ ) = ( >>| )
  let ( and+ ) = both
end

module List = struct
  type ('a, 'error) t = ('a, 'error) result list

  let rec all = function
    | [] -> Ok []
    | Ok x :: xs -> map (all xs) ~f:(fun xs -> x :: xs)
    | Error error :: _xs -> Error error
  ;;
end
