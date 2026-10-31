module T = struct
  include StdLabels.String

  let to_dyn = Dyn.string
end

include T
module Set = Set.Make (T)
module Map = Map.Make (T)

let is_empty s = length s == 0

let lsplit2 s ~on =
  match index_opt s on with
  | None -> None
  | Some i -> Some (sub s ~pos:0 ~len:i, sub s ~pos:(i + 1) ~len:(length s - i - 1))
;;

let split_on_char_nonempty s ~sep =
  match Nonempty_list.of_list_opt (split_on_char s ~sep) with
  | None ->
    (* [split_on_char] never returns empty lists *)
    failwith "unreachable"
  | Some l -> l
;;

let rec check_prefix s ~prefix len i =
  i = len || (get s i = get prefix i && check_prefix s ~prefix len (i + 1))
;;

let is_prefix s ~prefix =
  let len = length s in
  let prefix_len = length prefix in
  len >= prefix_len && check_prefix s ~prefix prefix_len 0
;;

let drop_prefix s ~prefix =
  if is_prefix s ~prefix
  then
    if length s = length prefix
    then Some ""
    else Some (sub s ~pos:(length prefix) ~len:(length s - length prefix))
  else None
;;
