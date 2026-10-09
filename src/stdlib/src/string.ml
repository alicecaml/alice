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
