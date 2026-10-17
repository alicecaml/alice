open! Alice_stdlib

module T = struct
  type t =
    | Unix
    | Str

  let to_dyn = function
    | Unix -> Dyn.variant "Unix" []
    | Str -> Dyn.variant "Str" []
  ;;

  let equal a b =
    match a, b with
    | Unix, Unix -> true
    | Unix, _ -> false
    | Str, Str -> true
    | Str, _ -> false
  ;;

  let compare a b =
    match a, b with
    | Unix, Unix -> 0
    | Unix, _ -> -1
    | _, Unix -> 1
    | Str, Str -> 0
  ;;
end

include T
module Map = Map.Make (T)
module Set = Set.Make (T)

let to_string = function
  | Unix -> "unix"
  | Str -> "str"
;;

let of_string_opt = function
  | "unix" -> Some Unix
  | "str" -> Some Str
  | _ -> None
;;

let of_string_res s =
  match of_string_opt s with
  | Some builtin -> Ok builtin
  | None -> Error [ Pp.textf "No such builtin module: %s" s ]
;;
