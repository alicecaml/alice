open! Alice_stdlib

type t = Dependency.t Package_name.Map.t

let empty = Package_name.Map.empty
let to_dyn = Package_name.Map.to_dyn Dependency.to_dyn
