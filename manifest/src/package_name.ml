open! Alice_stdlib
open Alice_error

type t = string

let to_dyn = Dyn.string

let validate s =
  let is_valid_first_char = function
    | 'a' .. 'z' -> true
    | _ -> false
  in
  let is_valid_later_char = function
    | 'a' .. 'z' | '0' .. '9' | '_' -> true
    | _ -> false
  in
  if String.is_empty s
  then Error [ Pp.text "Package name may not be empty!" ]
  else (
    let first_char = String.get s 0 in
    match is_valid_first_char first_char with
    | false ->
      Error
        [ Pp.textf "Package names must start with a lowercase letter. Got: %c" first_char
        ]
    | true ->
      let invalid_char =
        String.fold_left s ~init:None ~f:(fun invalid_char char ->
          match invalid_char with
          | Some _ -> invalid_char
          | None -> if is_valid_later_char char then invalid_char else Some char)
      in
      (match invalid_char with
       | Some invalid_char ->
         Error
           [ Pp.textf
               "Package names may consist of only lowercase letters, digits, and \
                underscores. Got: %c"
               invalid_char
           ]
       | None -> Ok ()))
;;

let of_string_res s = validate s |> Result.map ~f:(fun () -> s)

let of_string s =
  match validate s with
  | Error pps -> user_error pps
  | Ok () -> s
;;

let to_string t = t
