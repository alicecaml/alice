include MoreLabels.Map

module type S = sig
  include S

  val find : 'a t -> key -> 'a option
  val set : 'a t -> key -> 'a -> 'a t
  val of_list : (key * 'a) list -> ('a t, key * 'a * 'a) Result.t
end

module Make (Key : OrderedType) : S with type key = Key.t = struct
  include MoreLabels.Map.Make (struct
      type t = Key.t

      let compare = Key.compare
    end)

  let find key t = find_opt t key
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
end
