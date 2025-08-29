open! Alice_stdlib

type t = Exact of Semantic_version.t

let to_dyn = function
  | Exact version -> Dyn.variant "Exact" [ Semantic_version.to_dyn version ]
;;

let matches ~version = function
  | Exact version_ -> Semantic_version.equal version_ version
;;

let to_string = function
  | Exact version -> Semantic_version.to_string version
;;

let of_string_res s =
  Semantic_version.of_string_res s |> Result.map ~f:(fun version -> Exact version)
;;

let of_string s =
  match of_string_res s with
  | Ok t -> t
  | Error e ->
    Alice_print.pps_eprintln e;
    exit 1
;;
