open! Alice_stdlib

type t = Dependency.t Package_name.Map.t

let empty = Package_name.Map.empty
let equal = Package_name.Map.equal ~cmp:Dependency.equal
let to_dyn = Package_name.Map.to_dyn Dependency.to_dyn
let names = Package_name.Map.keys
