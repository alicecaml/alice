open! Alice_stdlib
open Filename

let%test "is_root" =
  if Sys.win32
  then List.all [ is_root "C:\\"; is_root "D:\\"; is_root "/" ]
  else is_root "/"
;;

let%test "normalize_error" =
  let f t =
    match normalize t with
    | Error `Would_traverse_beyond_the_start_of_absolute_path -> true
    | _ -> false
  in
  [ [ f "/.."; f "/a/b/../../.."; f "/../a"; f "/a/b/../../../c" ]
  ; (if Sys.win32 then [ f "C:\\.."; f "C:\\a\\..\\.." ] else [])
  ]
  |> List.concat
  |> List.all
;;

let%test "normalize" =
  let f a b =
    let norm = normalize a |> Result.get_ok in
    if equal_components norm b
    then true
    else (
      print_endline
        (sprintf "%S should normalize to %S but instead it normalizes to %S" a b norm);
      false)
  in
  List.all
    [ f "" "."
    ; f "a" "a"
    ; f "/" "/"
    ; f "/a" "/a"
    ; f "a/b" "a/b"
    ; f ".." ".."
    ; f "." "."
    ; f "../.." "../.."
    ; f "../a" "../a"
    ; f "/." "/"
    ; f "a/./b" "a/b"
    ; f "a/../b" "b"
    ; f "/a/.." "/"
    ]
;;

let%test "chop_prefix" =
  let f ~prefix a b =
    let chopped = chop_prefix a ~prefix in
    if equal_components chopped b
    then true
    else (
      print_endline
        (sprintf "[chop_prefix %S ~prefix:%S], expected %S, got %S" a prefix b chopped);
      false)
  in
  List.all
    [ f "/a" ~prefix:"/" "a"
    ; f "/a/b" ~prefix:"/a" "b"
    ; f "a/b" ~prefix:"a" "b"
    ; f "a" ~prefix:"a" "."
    ; f "../a" ~prefix:".." "a"
    ; f "a/b/c/d" ~prefix:"a/b" "c/d"
    ]
;;
