module T = struct
  include StdLabels.String

  let to_dyn = Dyn.string
end

include T
module Set = Set.Make (T)
module Map = Map.Make (T)

let lsplit2 s ~on =
  match index_opt s on with
  | None -> None
  | Some i -> Some (sub s ~pos:0 ~len:i, sub s ~pos:(i + 1) ~len:(length s - i - 1))
;;
