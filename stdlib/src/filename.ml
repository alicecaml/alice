module T = struct
  include Stdlib.Filename

  type t = string

  let compare = String.compare
end

include T
module Map = Map.Make (T)
module Set = Set.Make (T)

let equal = String.equal
let has_extension t ~ext = String.equal (extension t) ext

let replace_extension t ~ext =
  assert (Char.equal (String.get ext 0) '.');
  let without_extension = chop_extension t in
  concat without_extension ext
;;
