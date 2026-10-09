module type S = sig
  include MoreLabels.Hashtbl.S

  val find_or_add : 'a t -> key -> f:(key -> 'a) -> 'a
end

module Make (H : sig
    include MoreLabels.Hashtbl.HashedType
  end) =
struct
  include MoreLabels.Hashtbl.Make (H)

  let find_or_add t key ~f =
    match find_opt t key with
    | Some x -> x
    | None ->
      let x = f key in
      replace t ~key ~data:x;
      x
  ;;
end
