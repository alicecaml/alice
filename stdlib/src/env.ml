module Variable = struct
  type t =
    { name : string
    ; value : string
    }

  let parse s =
    match String.lsplit2 s ~on:'=' with
    | None -> { name = s; value = "" }
    | Some (name, value) -> { name; value }
  ;;

  let to_string { name; value } = Printf.sprintf "%s=%s" name value
  let equal t { name; value } = String.equal t.name name && String.equal t.value value

  let to_dyn { name; value } =
    Dyn.record [ "name", Dyn.string name; "value", Dyn.string value ]
  ;;
end

type t = Variable.t list
type raw = string array

let empty = []
let equal = List.equal ~eq:Variable.equal
let to_dyn = Dyn.list Variable.to_dyn
let of_raw raw = Array.to_list raw |> List.map ~f:Variable.parse
let to_raw t = List.map t ~f:Variable.to_string |> Array.of_list

let get_opt t ~name =
  List.find_map t ~f:(fun (variable : Variable.t) ->
    if String.equal variable.name name then Some variable.value else None)
;;

let find_by_name_opt t ~f =
  List.find_map t ~f:(fun (variable : Variable.t) ->
    if f variable.name then Some variable.value else None)
;;

let find_name_opt t ~f =
  List.find_map t ~f:(fun (variable : Variable.t) ->
    if f variable.name then Some variable.name else None)
;;

let contains t ~name =
  List.exists t ~f:(fun (variable : Variable.t) -> String.equal variable.name name)
;;

let set t ~name ~value =
  let variable = { Variable.name; value } in
  if contains t ~name
  then
    List.map t ~f:(fun (v : Variable.t) ->
      if String.equal v.name name then variable else v)
  else variable :: t
;;
