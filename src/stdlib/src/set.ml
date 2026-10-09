include MoreLabels.Set

module type S = sig
  include S

  val to_dyn : t -> Dyn.t
  val union_all : t list -> t
end

module type Ord = sig
  include OrderedType

  val to_dyn : t -> Dyn.t
end

module Make (Ord : Ord) = struct
  include MoreLabels.Set.Make (struct
      type t = Ord.t

      let compare = Ord.compare
    end)

  let to_dyn t = Dyn.Set (to_list t |> List.map ~f:Ord.to_dyn)
  let union_all ts = List.fold_left ts ~init:empty ~f:union
end
