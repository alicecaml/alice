open! Alice_stdlib

let int_of_string_round_trip_check s =
  match int_of_string_opt s with
  | None -> `Not_int
  | Some i -> if String.equal s (string_of_int i) then `Int i else `Int_no_round_trip i
;;

module Pre_release = struct
  module Part = struct
    (* Distinguish between identifiers that look like numbers and other
       identifiers, as numeric identifiers are compared numerically and other
       identifiers are compared lexicographically. *)
    type t =
      | Int of int
      | String of string

    let to_dyn = function
      | Int int -> Dyn.variant "Int" [ Dyn.int int ]
      | String string -> Dyn.variant "String" [ Dyn.string string ]
    ;;

    let to_string = function
      | Int int -> string_of_int int
      | String string -> string
    ;;

    let of_string s =
      match int_of_string_round_trip_check s with
      | `Not_int | `Int_no_round_trip _ ->
        (* Only consider the string to be an int if it round trips back to
           the same string so that strings representing integers with
           redundant leading zeroes keep their leading zeroes. *)
        String s
      | `Int i -> Int i
    ;;
  end

  type t = Part.t Nonempty_list.t

  let to_dyn = Nonempty_list.to_dyn Part.to_dyn

  let to_string t =
    Nonempty_list.to_list t |> List.map ~f:Part.to_string |> String.concat ~sep:"."
  ;;
end

module Metadata = struct
  type t = string Nonempty_list.t

  let to_dyn = Nonempty_list.to_dyn Dyn.string
  let to_string t = Nonempty_list.to_list t |> String.concat ~sep:"."
end

type t =
  { major : int
  ; minor : int
  ; patch : int
  ; pre_release : Pre_release.t option
  ; metadata : Metadata.t option
  }

let to_dyn { major; minor; patch; pre_release; metadata } =
  Dyn.record
    [ "major", Dyn.int major
    ; "minor", Dyn.int minor
    ; "patch", Dyn.int patch
    ; "pre_release", Dyn.option Pre_release.to_dyn pre_release
    ; "metadata", Dyn.option Metadata.to_dyn metadata
    ]
;;

let to_string { major; minor; patch; pre_release; metadata } =
  let base = sprintf "%d.%d.%d" major minor patch in
  let with_pre_release =
    match pre_release with
    | None -> base
    | Some pre_release -> sprintf "%s-%s" base (Pre_release.to_string pre_release)
  in
  match metadata with
  | None -> with_pre_release
  | Some metadata -> sprintf "%s+%s" with_pre_release (Metadata.to_string metadata)
;;

let of_string_res s =
  let open Result.O in
  let int_of_component_res s =
    match int_of_string_round_trip_check s with
    | `Not_int ->
      Error
        [ Pp.textf
            "Version component %S is not an integer. Version components must be integers."
            s
        ]
    | `Int_no_round_trip i ->
      Error
        [ Pp.textf
            "Version component %S is not formatted as a decimal integer with no leading \
             zeroes (ie. it won't round-trip into a string). Replace it with: %d."
            s
            i
        ]
    | `Int i ->
      if i < 0
      then
        Error
          [ Pp.textf
              "Version component %S is negative. Version components must be non-negative \
               integers."
              s
          ]
      else Ok i
  in
  let validate_identifier s =
    let is_valid_char = function
      | 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '-' -> true
      | _ -> false
    in
    String.fold_left s ~init:(Ok ()) ~f:(fun acc ch ->
      match acc with
      | Error _ -> acc
      | Ok () ->
        if is_valid_char ch
        then acc
        else
          Error
            [ Pp.textf
                "Identifier %S contains invalid character '%c'. Identifiers in the \
                 pre-release and metadata section of a version number must consist \
                 entirely of alphanumeric characters and hyphens."
                s
                ch
            ])
  in
  let validate_identifiers parts =
    let+ _ : unit list =
      Nonempty_list.to_list parts |> List.map ~f:validate_identifier |> Result.List.all
    in
    ()
  in
  let without_metadata, metadata_s =
    match String.lsplit2 s ~on:'+' with
    | None -> s, None
    | Some (s, metadata_s) -> s, Some metadata_s
  in
  let major_minor_patch, pre_release_s =
    match String.lsplit2 without_metadata ~on:'-' with
    | None -> s, None
    | Some (s, pre_release_s) -> s, Some pre_release_s
  in
  let* major_s, minor_patch =
    match String.lsplit2 major_minor_patch ~on:'.' with
    | None ->
      Error
        [ Pp.textf "Invalid version number: %S. Lacks period separating components." s ]
    | Some (major_s, s) -> Ok (major_s, s)
  in
  let* minor_s, patch_s =
    match String.lsplit2 minor_patch ~on:'.' with
    | None ->
      Error
        [ Pp.textf "Invalid version number: %S. Lacks 3 period-delimited components." s ]
    | Some (minor_s, patch_s) -> Ok (minor_s, patch_s)
  in
  let* major = int_of_component_res major_s in
  let* minor = int_of_component_res minor_s in
  let* patch = int_of_component_res patch_s in
  let* pre_release =
    match pre_release_s with
    | None -> Ok None
    | Some pre_release_s ->
      let parts = String.split_on_char_nonempty pre_release_s ~sep:'.' in
      let+ () = validate_identifiers parts in
      Some (Nonempty_list.map parts ~f:Pre_release.Part.of_string)
  in
  let* metadata =
    match metadata_s with
    | None -> Ok None
    | Some metadata_s ->
      let parts = String.split_on_char_nonempty metadata_s ~sep:'.' in
      let+ () = validate_identifiers parts in
      Some parts
  in
  Ok { major; minor; patch; pre_release; metadata }
;;

let of_string s =
  match of_string_res s with
  | Ok t -> t
  | Error pps -> Alice_error.user_error pps
;;
