include MoreLabels.Map

module type S = sig
  include S

  val find_exn : 'a t -> key -> 'a
  val find : 'a t -> key -> 'a option
  val set : 'a t -> key -> 'a -> 'a t
  val of_list : (key * 'a) list -> ('a t, key * 'a * 'a) Result.t
  val of_list_exn : (key * 'a) list -> 'a t
end

module Make (Key : OrderedType) : S with type key = Key.t = struct
  include MoreLabels.Map.Make (struct
      type t = Key.t

      let compare = Key.compare
    end)

  let find_exn t key = find key t
  let find t key = find_opt key t
  let set t k v = add ~key:k ~data:v t

  let of_list =
    let rec loop acc = function
      | [] -> Result.Ok acc
      | (k, v) :: l ->
        (match find acc k with
         | None -> loop (set acc k v) l
         | Some v_old -> Error (k, v_old, v))
    in
    fun l -> loop empty l
  ;;

  let of_list_exn list =
    match of_list list with
    | Ok t -> t
    | Error _ -> raise (Invalid_argument "list contains duplicate key")
  ;;
end
