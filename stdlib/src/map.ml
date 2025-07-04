include MoreLabels.Map

module type S = sig
  include S

  val to_dyn : 'a Dyn.builder -> 'a t -> Dyn.t
  val of_list : (key * 'a) list -> ('a t, key * 'a * 'a) Result.t
  val of_list_exn : (key * 'a) list -> 'a t
  val keys : 'a t -> key list
end

module type Key = sig
  include OrderedType

  val to_dyn : t -> Dyn.t
end

module Make (Key : Key) : S with type key = Key.t = struct
  include MoreLabels.Map.Make (struct
      type t = Key.t

      let compare = Key.compare
    end)

  let to_dyn f t = Dyn.Map (to_list t |> List.map ~f:(fun (k, v) -> Key.to_dyn k, f v))

  let of_list =
    let rec loop acc = function
      | [] -> Result.Ok acc
      | (k, v) :: l ->
        (match find_opt k acc with
         | None -> loop (add acc ~key:k ~data:v) l
         | Some v_old -> Error (k, v_old, v))
    in
    fun l -> loop empty l
  ;;

  let of_list_exn list =
    match of_list list with
    | Ok t -> t
    | Error _ -> raise (Invalid_argument "list contains duplicate key")
  ;;

  let keys t = to_seq t |> Seq.map ~f:fst |> List.of_seq
end
