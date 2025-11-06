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
  then `Relative rest
  else if is_root first
  then `Absolute (first, rest)
  else
    failwith
      (Printf.sprintf
         "Expected %S to be an absolute path, but [is_root %S] is false."
         t
         t)
;;

let of_components components =
  let first, rest =
    match components with
    | `Relative [] -> current_dir_name, []
    | `Relative (first :: rest) -> first, rest
    | `Absolute (root, rest) -> root, rest
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
  | `Absolute (t_root, t_rest), `Absolute (prefix_root, prefix_rest) ->
    if String.equal t_root prefix_root then loop t_rest prefix_rest else None
  | `Relative t, `Relative prefix -> loop t prefix
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
  match components with
  | `Relative components ->
    let non_parent_stack, parent_prefix_count = loop components in
    let output_components = List.rev non_parent_stack in
    let parent_prefix =
      List.init ~len:parent_prefix_count ~f:(Fun.const parent_dir_name)
    in
    Ok (`Relative (parent_prefix @ output_components))
  | `Absolute (root, rest) ->
    let non_parent_stack, parent_prefix_count = loop rest in
    if parent_prefix_count > 0
    then Error `Would_traverse_beyond_the_start_of_absolute_path
    else Ok (`Absolute (root, List.rev non_parent_stack))
;;

let normalize t = Result.map (normalize_components (to_components t)) ~f:of_components
