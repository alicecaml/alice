open! Alice_stdlib
open Alice_hierarchy

type t = Local_directory of Either_path.t

let equal a b =
  match a, b with
  | Local_directory a, Local_directory b -> Either_path.equal a b
;;

let to_dyn = function
  | Local_directory path -> Dyn.variant "Local_directory" [ Either_path.to_dyn path ]
;;
