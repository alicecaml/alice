module T = struct
  include StdLabels.String

  let to_dyn = Dyn.string
end

include T
module Set = Set.Make (T)
module Map = Map.Make (T)
