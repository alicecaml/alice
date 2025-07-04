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
  let without_extension = chop_extension t in
  String.cat without_extension ext
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
  if String.starts_with ~prefix t
  then (
    let pos = String.length prefix in
    let len = String.length t - pos in
    Some (String.sub t ~pos ~len))
  else None
;;

let chop_prefix ~prefix t =
  match chop_prefix_opt ~prefix t with
  | Some t -> t
  | None ->
    raise
      (Invalid_argument (Printf.sprintf "Path %S doesn't start with prefix %S" t prefix))
;;
