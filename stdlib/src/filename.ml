module T = struct
  include Stdlib.Filename

  type t = string

  let compare = String.compare
  let to_dyn = Dyn.string
end

include T
module Map = Map.Make (T)
module Set = Set.Make (T)

let equal = String.equal
let has_extension t ~ext = String.equal (extension t) ext

let replace_extension t ~ext =
  assert (Char.equal (String.get ext 0) '.');
  match chop_extension t with
  | without_extension -> Some (String.cat without_extension ext)
  | exception Invalid_argument _ -> None
;;

let add_extension t ~ext =
  assert (Char.equal (String.get ext 0) '.');
  String.cat t ext
;;

let to_components t =
  let rec loop t =
    if equal t (dirname t)
    then
      (* This happens at the top of a relative path ("." in unix - even
         if the original path did not begin with a ".") or the root of
         the filesystem in the case of absolute paths. *)
      Nonempty_list.singleton t
    else Nonempty_list.cons (basename t) (loop (dirname t))
  in
  loop t |> Nonempty_list.rev
;;

let chop_prefix_opt ~prefix t =
  let rec loop components prefix_components =
    match components, prefix_components with
    | [], [] ->
      (* The path and the prefix are the same. *)
      Some current_dir_name
    | [], _ :: _ ->
      (* The given prefix is not a prefix of the path. *)
      None
    | _ :: _, [] ->
      (* Reassemble the remainder of the path. *)
      Some (String.concat components ~sep:dir_sep)
    | components_hd :: components_tl, prefix_hd :: prefix_tl ->
      if String.equal components_hd prefix_hd then loop components_tl prefix_tl else None
  in
  loop
    (to_components t |> Nonempty_list.to_list)
    (to_components prefix |> Nonempty_list.to_list)
;;

let chop_prefix ~prefix t =
  match chop_prefix_opt ~prefix t with
  | Some t -> t
  | None ->
    raise
      (Invalid_argument (Printf.sprintf "Path %S doesn't start with prefix %S" t prefix))
;;

let is_root t = (not (equal t current_dir_name)) && equal (basename t) (dirname t)
