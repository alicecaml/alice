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

  type either =
    [ `Root of root_t
    | `Non_root of non_root_t
    ]

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

  let to_filename : type is_root. is_root t -> Filename.t = function
    | Root filename -> filename
    | Non_root filename -> filename
  ;;

  let concat : type is_root. is_root t -> Basename.t -> non_root_t =
    fun t basename ->
    Non_root (Filename.concat (to_filename t) (Basename.to_filename basename))
  ;;

  let compare a b = Filename.compare (to_filename a) (to_filename b)
  let extension (Non_root filename) = Filename.extension filename
  let has_extension (Non_root filename) ~ext = Filename.has_extension filename ~ext

  let replace_extension (Non_root filename) ~ext =
    Non_root (Filename.replace_extension filename ~ext)
  ;;

  let add_extension (Non_root filename) ~ext =
    Non_root (Filename.replace_extension filename ~ext)
  ;;

  let remove_extension (Non_root filename) = Non_root (Filename.remove_extension filename)
  let parent (Non_root filename) = of_filename (Filename.dirname filename)
  let basename (Non_root filename) = Basename.of_filename (Filename.basename filename)
end

module Path = struct
  type absolute = |
  type relative = |

  type _ t =
    | Absolute : Filename.t -> absolute t
    | Relative : Filename.t -> relative t

  module Kind = struct
    type _ t =
      | Absolute : absolute t
      | Relative : relative t

    let absolute = Absolute
    let relative = Relative
  end

  type 'a with_path = { f : 'kind. 'kind t -> 'a }

  let equal : type a. a t -> a t -> bool =
    fun a b ->
    match a, b with
    | Absolute a, Absolute b | Relative a, Relative b -> Filename.equal a b
  ;;

  let to_dyn : type a. a t -> Dyn.t = function
    | Absolute filename -> Dyn.variant "Absolute" [ Filename.to_dyn filename ]
    | Relative filename -> Dyn.variant "Relative" [ Filename.to_dyn filename ]
  ;;

  let to_filename : type a. a t -> Filename.t = function
    | Absolute filename -> filename
    | Relative filename -> filename
  ;;

  let of_filename filename =
    if Filename.is_relative filename
    then `Relative (Relative filename)
    else `Absolute (Absolute filename)
  ;;

  let hash t = to_filename t |> String.hash

  let absolute filename =
    match of_filename filename with
    | `Absolute path -> path
    | `Relative _ -> Alice_error.panic [ Pp.textf "Not an absolute path: %s" filename ]
  ;;

  let relative filename =
    match of_filename filename with
    | `Absolute _ -> Alice_error.panic [ Pp.textf "Not a relative path: %s" filename ]
    | `Relative path -> path
  ;;

  let kind : type a. a t -> a Kind.t = function
    | Absolute _ -> Kind.Absolute
    | Relative _ -> Kind.Relative
  ;;

  let of_filename_checked : type a. a Kind.t -> Filename.t -> a t =
    fun kind filename ->
    match kind with
    | Kind.Absolute -> absolute filename
    | Kind.Relative -> relative filename
  ;;

  let current_dir = Relative Filename.current_dir_name

  let map_filename : type a. a t -> f:(Filename.t -> Filename.t) -> a t =
    fun t ~f ->
    match t with
    | Absolute filename -> Absolute (f filename)
    | Relative filename -> Relative (f filename)
  ;;

  let concat : type a. a t -> relative t -> a t =
    fun abs_or_rel rel ->
    map_filename abs_or_rel ~f:(fun filename ->
      Filename.concat filename (to_filename rel))
  ;;

  let concat_multi : type a. a t -> relative t list -> a t =
    fun abs_or_rel rels ->
    map_filename abs_or_rel ~f:(fun filename ->
      List.fold_left rels ~init:filename ~f:(fun acc rel ->
        Filename.concat acc (to_filename rel)))
  ;;

  let chop_prefix_opt ~prefix t =
    Option.map
      (Filename.chop_prefix_opt ~prefix:(to_filename prefix) (to_filename t))
      ~f:(fun filename -> Relative filename)
  ;;

  let chop_prefix ~prefix t =
    Relative (Filename.chop_prefix ~prefix:(to_filename prefix) (to_filename t))
  ;;

  let extension t = Filename.extension (to_filename t)
  let has_extension t ~ext = Filename.has_extension (to_filename t) ~ext
  let replace_extension t ~ext = map_filename t ~f:(Filename.replace_extension ~ext)
  let add_extension t ~ext = map_filename t ~f:(Filename.add_extension ~ext)
  let remove_extension t = map_filename t ~f:Filename.remove_extension
  let dirname t = map_filename t ~f:Filename.dirname

  let basename t =
    match chop_prefix_opt t ~prefix:(dirname t) with
    | Some x -> x
    | None -> current_dir
  ;;

  let match_
    : type a. a t -> absolute:(absolute t -> 'b) -> relative:(relative t -> 'b) -> 'b
    =
    fun t ~absolute ~relative ->
    match t with
    | Absolute filename -> absolute (Absolute filename)
    | Relative filename -> relative (Relative filename)
  ;;

  module Make (T : sig
      type t

      val compare : t -> t -> int
      val to_dyn : t -> Dyn.t
      val equal : t -> t -> bool
      val hash : t -> int
      val to_filename : t -> Filename.t
      val of_filename_internal : Filename.t -> t
      val map_filename : t -> f:(Filename.t -> Filename.t) -> t
    end) =
  struct
    include T
    module Map = Map.Make (T)
    module Set = Set.Make (T)
    module Hashtbl = Hashtbl.Make (T)

    let equal a b = Filename.equal (to_filename a) (to_filename b)
    let has_extension t ~ext = Filename.has_extension (to_filename t) ~ext

    let replace_extension t ~ext =
      Filename.replace_extension (to_filename t) ~ext |> of_filename_internal
    ;;

    let add_extension t ~ext =
      Filename.add_extension (to_filename t) ~ext |> of_filename_internal
    ;;

    let remove_extension t =
      Filename.remove_extension (to_filename t) |> of_filename_internal
    ;;

    let extension t = Filename.extension (to_filename t)
    let dirname t = map_filename t ~f:Filename.dirname
  end

  module Absolute = struct
    include Make (struct
        type nonrec t = absolute t

        let compare (Absolute a) (Absolute b) = Filename.compare a b
        let equal (Absolute a) (Absolute b) = Filename.equal a b
        let to_dyn (Absolute t) = Filename.to_dyn t
        let to_filename (Absolute t) = t
        let of_filename_internal t = Absolute t
        let map_filename = map_filename
        let hash = hash
      end)
  end

  module Relative = struct
    include Make (struct
        type nonrec t = relative t

        let compare (Relative a) (Relative b) = Filename.compare a b
        let equal (Relative a) (Relative b) = Filename.equal a b
        let to_dyn (Relative t) = Filename.to_dyn t
        let to_filename (Relative t) = t
        let of_filename_internal t = Relative t
        let map_filename = map_filename
        let hash = hash
      end)
  end

  module Either = struct
    include Make (struct
        type t =
          [ `Absolute of Absolute.t
          | `Relative of Relative.t
          ]

        let compare a b =
          match a, b with
          | `Absolute a, `Absolute b -> Absolute.compare a b
          | `Relative a, `Relative b -> Relative.compare a b
          | `Absolute _, `Relative _ -> -1
          | `Relative _, `Absolute _ -> 1
        ;;

        let equal a b =
          match a, b with
          | `Absolute a, `Absolute b -> Absolute.equal a b
          | `Relative a, `Relative b -> Relative.equal a b
          | `Absolute _, `Relative _ | `Relative _, `Absolute _ -> false
        ;;

        let to_dyn = function
          | `Absolute absolute -> Dyn.variant "Absolute" [ Absolute.to_dyn absolute ]
          | `Relative relative -> Dyn.variant "Relative" [ Relative.to_dyn relative ]
        ;;

        let to_filename = function
          | `Absolute absolute -> Absolute.to_filename absolute
          | `Relative relative -> Relative.to_filename relative
        ;;

        let of_filename_internal = of_filename

        let map_filename t ~f =
          match t with
          | `Absolute absolute -> `Absolute (Absolute.map_filename absolute ~f)
          | `Relative relative -> `Relative (Relative.map_filename relative ~f)
        ;;

        let hash = function
          | `Absolute absolute -> hash absolute
          | `Relative relative -> hash relative
        ;;
      end)

    let with_ with_path t =
      match t with
      | `Absolute absolute -> with_path.f absolute
      | `Relative relative -> with_path.f relative
    ;;
  end

  let with_filename with_path filename = of_filename filename |> Either.with_ with_path

  let to_either : type a. a t -> Either.t = function
    | Absolute absolute -> `Absolute (Absolute absolute)
    | Relative relative -> `Relative (Relative relative)
  ;;

  let compare : type a. a t -> a t -> int =
    fun a b ->
    match a, b with
    | Absolute a, Absolute b -> Filename.compare a b
    | Relative a, Relative b -> Filename.compare a b
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

module File = struct
  type 'path_kind kind =
    | Regular
    | Link
    | Dir of 'path_kind t list
    | Unknown

  and 'path_kind t =
    { path : 'path_kind Path.t
    ; kind : 'path_kind kind
    }

  let path { path; _ } = path
  let kind { kind; _ } = kind

  let rec to_dyn { path; kind } =
    Dyn.record [ "path", Path.to_dyn path; "kind", kind_to_dyn kind ]

  and kind_to_dyn = function
    | Regular -> Dyn.variant "Regular" []
    | Link -> Dyn.variant "Link" []
    | Dir contents -> Dyn.variant "Dir" [ Dyn.list to_dyn contents ]
    | Unknown -> Dyn.variant "Unknown" []
  ;;

  type 'path_kind dir =
    { path : 'path_kind Path.t
    ; contents : 'path_kind t list
    }

  let dir_to_dyn { path; contents } =
    Dyn.record [ "path", Path.to_dyn path; "contents", Dyn.list to_dyn contents ]
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

  let rec map_paths { path; kind } ~f : 'b t =
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

  let compare_by_path a b = Path.compare (path a) (path b)
end

module Dir = struct
  type 'path_kind t = 'path_kind File.dir =
    { path : 'path_kind Path.t
    ; contents : 'path_kind File.t list
    }

  let to_dyn = File.dir_to_dyn

  let to_relative { path; contents } =
    let contents =
      List.map contents ~f:(File.map_paths ~f:(Path.chop_prefix ~prefix:path))
    in
    { path = Path.current_dir; contents }
  ;;

  let path { path; _ } = path
  let contents { contents; _ } = contents

  let contains t path =
    List.exists (contents t) ~f:(fun file -> Path.equal (File.path file) path)
  ;;
end

let ( / ) = Path.concat
