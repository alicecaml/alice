open! Alice_stdlib
open Alice_error

module Basename = struct
  type t = Filename.t

  let to_dyn = Filename.to_dyn
  let equal = Filename.equal

  let check_filename filename =
    if Filename.is_implicit filename
    then
      if String.is_empty filename
      then Error `Empty
      else if Filename.equal (Filename.basename filename) filename
      then Ok ()
      else Error `Multiple_path_components
    else Error `Not_implicit
  ;;

  let of_filename_result filename =
    check_filename filename |> Result.map ~f:(Fun.const filename)
  ;;

  let of_filename filename =
    match of_filename_result filename with
    | Ok t -> t
    | Error `Empty -> panic [ Pp.text "Filename may not be empty." ]
    | Error `Multiple_path_components ->
      panic [ Pp.textf "%S is not a basename as it has multiple components." filename ]
    | Error `Not_implicit ->
      panic
        [ Pp.textf "%S is not a basename as it is not an implicit relative path." filename
        ]
  ;;

  let to_filename t = t
  let compare = Filename.compare
  let extension t = Filename.extension t
  let has_extension t ~ext = Filename.has_extension t ~ext

  let replace_extension t ~ext =
    match Filename.replace_extension t ~ext with
    | Some filename -> filename
    | None -> panic [ Pp.textf "Path %S has no extension to replace." t ]
  ;;

  let add_extension t ~ext = Filename.add_extension t ~ext
  let remove_extension t = Filename.remove_extension t
end

module Relative_path = struct
  type t = Filename.t

  let to_dyn = Filename.to_dyn
  let equal = Filename.equal
  let of_basename t = t

  let of_filename_result filename =
    if Filename.is_relative filename then Ok filename else Error `Not_relative
  ;;

  let of_filename filename =
    match of_filename_result filename with
    | Ok t -> t
    | Error `Not_relative -> panic [ Pp.textf "%S is not a relative path." filename ]
  ;;

  let to_filename t = t
end

module Absolute_path = struct
  open Type_bool

  type 'is_root t =
    | Root : Filename.t -> true_t t
      (* We still need to store the filename in this case because on windows
         each drive has a separate root directory. *)
    | Non_root : Filename.t -> false_t t

  type root_t = true_t t
  type non_root_t = false_t t

  let to_dyn : type is_root. is_root t -> Dyn.t = function
    | Root filename -> Dyn.variant "Root" [ Filename.to_dyn filename ]
    | Non_root filename -> Dyn.variant "Non_root" [ Filename.to_dyn filename ]
  ;;

  let equal : type is_root. is_root t -> is_root t -> bool =
    fun a b ->
    match a, b with
    | Root a, Root b -> Filename.equal a b
    | Non_root a, Non_root b -> Filename.equal a b
  ;;

  let of_filename_result filename =
    if Filename.is_relative filename
    then Error `Not_absolute
    else if Filename.is_root filename
    then Ok (`Root (Root filename))
    else Ok (`Non_root (Non_root filename))
  ;;

  let of_filename filename =
    match of_filename_result filename with
    | Ok either -> either
    | Error `Not_absolute -> panic [ Pp.textf "%S is not an absolute path." filename ]
  ;;

  let of_filename_assert_non_root filename =
    match of_filename filename with
    | `Root _ -> panic [ Pp.textf "%S is a root directory" filename ]
    | `Non_root t -> t
  ;;

  let to_filename : type is_root. is_root t -> Filename.t = function
    | Root filename -> filename
    | Non_root filename -> filename
  ;;

  let concat_relative t relative =
    let filename = Filename.concat (to_filename t) (Relative_path.to_filename relative) in
    match Filename.normalize filename with
    | Error `Would_traverse_beyond_the_start_of_absolute_path ->
      Error (`Would_traverse_beyond_the_start_of_absolute_path filename)
    | Ok filename_normalized -> Ok (of_filename filename_normalized)
  ;;

  let concat_relative_exn t relative =
    match concat_relative t relative with
    | Ok x -> x
    | Error (`Would_traverse_beyond_the_start_of_absolute_path filename) ->
      user_exn
        [ Pp.textf "Invalid path %S would traverse beyond the filesystem root." filename ]
  ;;

  let concat_basename t basename =
    Non_root (Filename.concat (to_filename t) (Basename.to_filename basename))
  ;;

  let compare a b = Filename.compare (to_filename a) (to_filename b)
  let extension (Non_root filename) = Filename.extension filename
  let has_extension (Non_root filename) ~ext = Filename.has_extension filename ~ext

  let replace_extension (Non_root filename) ~ext =
    match Filename.replace_extension filename ~ext with
    | Some filename -> Non_root filename
    | None -> panic [ Pp.textf "Path %S has no extension to replace." filename ]
  ;;

  let add_extension (Non_root filename) ~ext =
    Non_root (Filename.add_extension filename ~ext)
  ;;

  let remove_extension (Non_root filename) = Non_root (Filename.remove_extension filename)
  let parent (Non_root filename) = of_filename (Filename.dirname filename)
  let basename (Non_root filename) = Basename.of_filename (Filename.basename filename)

  let is_root : type is_root. is_root t -> is_root Type_bool.t = function
    | Root _ -> True
    | Non_root _ -> False
  ;;

  module Non_root = struct
    type t = non_root_t

    let compare = compare
    let to_dyn = to_dyn
  end

  module Non_root_map = Map.Make (Non_root)

  module Root_or_non_root = struct
    type t =
      [ `Root of root_t
      | `Non_root of non_root_t
      ]

    let to_dyn = function
      | `Root root -> Dyn.variant "Root" [ to_dyn root ]
      | `Non_root non_root -> Dyn.variant "Non_root" [ to_dyn non_root ]
    ;;

    let equal a b =
      match a, b with
      | `Root a, `Root b -> equal a b
      | `Root _, _ -> false
      | `Non_root a, `Non_root b -> equal a b
      | `Non_root _, _ -> false
    ;;

    let assert_non_root = function
      | `Root path -> panic [ Pp.textf "%S is a root directory" (to_filename path) ]
      | `Non_root path -> path
    ;;

    let to_filename = function
      | `Root path -> to_filename path
      | `Non_root path -> to_filename path
    ;;

    let concat_relative t relative =
      match t with
      | `Root path -> concat_relative path relative
      | `Non_root path -> concat_relative path relative
    ;;

    let concat_relative_exn t relative =
      match t with
      | `Root path -> concat_relative_exn path relative
      | `Non_root path -> concat_relative_exn path relative
    ;;

    let concat_basename t basename =
      match t with
      | `Root path -> concat_basename path basename
      | `Non_root path -> concat_basename path basename
    ;;
  end
end

module Either_path = struct
  type t =
    [ `Absolute of Absolute_path.Root_or_non_root.t
    | `Relative of Relative_path.t
    ]

  let to_dyn = function
    | `Absolute absolute ->
      Dyn.variant "Absolute" [ Absolute_path.Root_or_non_root.to_dyn absolute ]
    | `Relative relative -> Dyn.variant "Relative" [ Relative_path.to_dyn relative ]
  ;;

  let equal a b =
    match a, b with
    | `Absolute a, `Absolute b -> Absolute_path.Root_or_non_root.equal a b
    | `Absolute _, _ -> false
    | `Relative a, `Relative b -> Relative_path.equal a b
    | `Relative _, _ -> false
  ;;

  let of_filename filename =
    if Filename.is_relative filename
    then `Relative (Relative_path.of_filename filename)
    else `Absolute (Absolute_path.of_filename filename)
  ;;

  let to_filename = function
    | `Absolute path -> Absolute_path.Root_or_non_root.to_filename path
    | `Relative path -> Relative_path.to_filename path
  ;;
end

module File_non_root = struct
  type kind =
    | Regular
    | Link
    | Dir of t list
    | Unknown

  and t =
    { path : Absolute_path.non_root_t
    ; kind : kind
    }

  let path { path; _ } = path
  let kind { kind; _ } = kind

  let rec to_dyn { path; kind } =
    Dyn.record [ "path", Absolute_path.to_dyn path; "kind", kind_to_dyn kind ]

  and kind_to_dyn = function
    | Regular -> Dyn.variant "Regular" []
    | Link -> Dyn.variant "Link" []
    | Dir contents -> Dyn.variant "Dir" [ Dyn.list to_dyn contents ]
    | Unknown -> Dyn.variant "Unknown" []
  ;;

  type dir =
    { path : Absolute_path.non_root_t
    ; contents : t list
    }

  let dir_to_dyn { path; contents } =
    Dyn.record [ "path", Absolute_path.to_dyn path; "contents", Dyn.list to_dyn contents ]
  ;;

  let as_dir { kind; path } =
    match kind with
    | Dir contents -> Some { path; contents }
    | _ -> None
  ;;

  let is_dir t =
    match t.kind with
    | Dir _ -> true
    | _ -> false
  ;;

  let is_regular_or_link t =
    match t.kind with
    | Regular | Link -> true
    | _ -> false
  ;;

  let rec traverse_bottom_up t ~f =
    match t.kind with
    | Regular | Link -> f t
    | Dir contents ->
      List.iter contents ~f:(traverse_bottom_up ~f);
      f t
    | Unknown -> ()
  ;;

  let rec map_paths { path; kind } ~f =
    let path = f path in
    let kind =
      match kind with
      | Regular -> Regular
      | Link -> Link
      | Unknown -> Unknown
      | Dir contents -> Dir (List.map contents ~f:(map_paths ~f))
    in
    { path; kind }
  ;;

  let compare_by_path a b = Absolute_path.compare (path a) (path b)
end

module Dir_non_root = struct
  type t = File_non_root.dir =
    { path : Absolute_path.non_root_t
    ; contents : File_non_root.t list
    }

  let to_dyn = File_non_root.dir_to_dyn
  let path { path; _ } = path
  let contents { contents; _ } = contents

  let contains t path =
    List.exists (contents t) ~f:(fun file ->
      Absolute_path.equal (File_non_root.path file) path)
  ;;
end

let ( / ) = Absolute_path.concat_basename
