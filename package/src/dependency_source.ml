open! Alice_stdlib
open Alice_hierarchy

type t = Local_directory of Path.Either.t

let equal a b =
  match a, b with
  | Local_directory a, Local_directory b -> Path.Either.equal a b
;;

let to_dyn = function
  | Local_directory path -> Dyn.variant "Local_directory" [ Path.Either.to_dyn path ]
;;
