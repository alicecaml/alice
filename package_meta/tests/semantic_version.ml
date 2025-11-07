open Alice_stdlib
open Alice_package_meta.Semantic_version

let of_string_exn s =
  match of_string s with
  | Ok t -> t
  | Error e ->
    Alice_error.User_error.eprint e;
    exit 1
;;

let%test "basic" = Result.is_ok (of_string "1.2.3")
let%test "multiple digits" = Result.is_ok (of_string "14.25.36")

let%test "pre_release" =
  match pre_release_string @@ of_string_exn "9.8.7-beta" with
  | None -> false
  | Some pre_release -> String.equal pre_release "beta"
;;

let%test "metadata" =
  match metadata_string @@ of_string_exn "1.0.0+foo" with
  | None -> false
  | Some metadata -> String.equal metadata "foo"
;;

let%test "pre_release and metadata" =
  let t = of_string_exn "2.2.2-rc1+blah" in
  let pre_release = pre_release_string t |> Option.get in
  let metadata = metadata_string t |> Option.get in
  String.equal pre_release "rc1" && String.equal metadata "blah"
;;

let%test "metadata contains dash" =
  let metadata = of_string_exn "2.3.4+foo-bar" |> metadata_string |> Option.get in
  String.equal metadata "foo-bar"
;;

let%test "invalid versions" =
  let versions =
    [ ""
    ; "foo"
    ; "4"
    ; "4.2"
    ; "1.2.3.4"
    ; "1.2.3-"
    ; "1.3.4+"
    ; "1.3.4-+"
    ; "1.2.3-/"
    ; "1.2.3-beta+"
    ; "1.2.3-beta+/"
    ; "1.3.4+/"
    ]
  in
  List.for_all versions ~f:(fun version ->
    match of_string version with
    | Ok _ ->
      print_endline (sprintf "Should be invalid but was accepted: %s" version);
      false
    | Error _ -> true)
;;

let%test "precedence rules" =
  let lt a b =
    match compare_for_precedence (of_string_exn a) (of_string_exn b) with
    | -1 -> true
    | _ ->
      print_endline (sprintf "%s should be less than %s but it is not." a b);
      false
  in
  List.for_all
    ~f:Fun.id
    [ lt "0.0.0" "0.0.1"
    ; lt "0.1.0" "0.2.0"
    ; lt "1.0.0" "2.0.0"
    ; lt "0.1.0" "0.1.2"
    ; lt "0.2.4" "0.4.2"
    ; lt "0.1.0" "1.0.0"
    ; lt "1.0.0-alpha" "1.0.0"
    ; lt "1.0.0-alpha" "1.0.0-alpha.1"
    ; lt "1.0.0-alpha.1" "1.0.0-alpha.2"
    ]
;;

let%test "metadata doesn't affect precedence" =
  compare_for_precedence (of_string_exn "1.0.0") (of_string_exn "1.0.0+foo") == 0
;;

