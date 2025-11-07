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
  if Char.equal (String.get ext 0) '.'
  then (
    match chop_extension t with
    | without_extension -> Some (String.cat without_extension ext)
    | exception Invalid_argument _ -> None)
  else failwith (Printf.sprintf "ext argument must begin with a '.', got %S" ext)
;;

let add_extension t ~ext =
  if Char.equal (String.get ext 0) '.'
  then String.cat t ext
  else failwith (Printf.sprintf "ext argument must begin with a '.', got %S" ext)
;;

let is_root t = (not (is_relative t)) && equal (dirname t) t

module Components = struct
  type nonrec t =
    | Relative of t list
    | Absolute of
        { root : t
        ; rest : t list
        }

  let equal a b =
    match a, b with
    | Relative a, Relative b -> List.equal ~eq:equal a b
    | Relative _, _ -> false
    | Absolute { root = a_root; rest = a_rest }, Absolute { root = b_root; rest = b_rest }
      -> equal a_root b_root && List.equal ~eq:equal a_rest b_rest
    | Absolute _, _ -> false
  ;;
end

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
  let (first :: rest) = loop t |> Nonempty_list.rev in
  if equal current_dir_name first
  then Components.Relative rest
  else if is_root first
  then Absolute { root = first; rest }
  else
    failwith
      (Printf.sprintf
         "Expected %S to be an absolute path, but [is_root %S] is false."
         t
         t)
;;

let equal_components a b = Components.equal (to_components a) (to_components b)

let of_components components =
  let first, rest =
    match (components : Components.t) with
    | Relative [] -> current_dir_name, []
    | Relative (first :: rest) -> first, rest
    | Absolute { root; rest } -> root, rest
  in
  List.fold_left rest ~init:first ~f:concat
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
  match to_components t, to_components prefix with
  | ( Absolute { root = t_root; rest = t_rest }
    , Absolute { root = prefix_root; rest = prefix_rest } ) ->
    if String.equal t_root prefix_root then loop t_rest prefix_rest else None
  | Relative t, Relative prefix -> loop t prefix
  | _ -> None
;;

let chop_prefix ~prefix t =
  match chop_prefix_opt ~prefix t with
  | Some t -> t
  | None ->
    raise
      (Invalid_argument (Printf.sprintf "Path %S doesn't start with prefix %S" t prefix))
;;

let normalize_components components =
  let rec loop remaining non_parent_stack parent_prefix_count =
    match remaining with
    | [] -> non_parent_stack, parent_prefix_count
    | path_x :: path_xs ->
      if equal parent_dir_name path_x
      then (
        match non_parent_stack with
        | [] -> loop path_xs non_parent_stack (parent_prefix_count + 1)
        | _ :: stack_xs -> loop path_xs stack_xs parent_prefix_count)
      else if equal current_dir_name path_x
      then loop path_xs non_parent_stack parent_prefix_count
      else loop path_xs (path_x :: non_parent_stack) parent_prefix_count
  in
  let loop components = loop components [] 0 in
  match (components : Components.t) with
  | Relative components ->
    let non_parent_stack, parent_prefix_count = loop components in
    let output_components = List.rev non_parent_stack in
    let parent_prefix =
      List.init ~len:parent_prefix_count ~f:(Fun.const parent_dir_name)
    in
    Ok (Components.Relative (parent_prefix @ output_components))
  | Absolute { root; rest } ->
    let non_parent_stack, parent_prefix_count = loop rest in
    if parent_prefix_count > 0
    then Error `Would_traverse_beyond_the_start_of_absolute_path
    else Ok (Absolute { root; rest = List.rev non_parent_stack })
;;

let normalize t = Result.map (normalize_components (to_components t)) ~f:of_components
