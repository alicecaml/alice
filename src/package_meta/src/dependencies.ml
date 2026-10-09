open! Alice_stdlib

type t = Dependency.t list

let empty = []
let equal = List.equal ~eq:Dependency.equal
let to_dyn = Dyn.list Dependency.to_dyn
let names = List.map ~f:Dependency.name
let to_list t = t

let of_list t =
  let rec loop seen remaining =
    match remaining with
    | [] -> Ok t
    | x :: xs ->
      let name = Dependency.name x in
      if Package_name.Set.mem name seen
      then Error (`Duplicate_name name)
      else (
        let seen = Package_name.Set.add name seen in
        loop seen xs)
  in
  loop Package_name.Set.empty t
;;
