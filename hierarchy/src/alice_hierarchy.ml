open! Alice_stdlib

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
      val to_filename : t -> Filename.t
      val of_filename_internal : Filename.t -> t
    end) =
  struct
    include T
    module Map = Map.Make (T)
    module Set = Set.Make (T)

    let equal a b = Filename.equal (to_filename a) (to_filename b)
    let has_extension t ~ext = Filename.has_extension (to_filename t) ~ext

    let replace_extension t ~ext =
      Filename.replace_extension (to_filename t) ~ext |> of_filename_internal
    ;;

    let extension t = Filename.extension (to_filename t)
  end

  module Absolute = Make (struct
      type nonrec t = absolute t

      let compare (Absolute a) (Absolute b) = Filename.compare a b
      let to_dyn (Absolute t) = Filename.to_dyn t
      let to_filename (Absolute t) = t
      let of_filename_internal t = Absolute t
    end)

  module Relative = Make (struct
      type nonrec t = relative t

      let compare (Relative a) (Relative b) = Filename.compare a b
      let to_dyn (Relative t) = Filename.to_dyn t
      let to_filename (Relative t) = t
      let of_filename_internal t = Relative t
    end)

  module Either = struct
    type t =
      [ `Absolute of Absolute.t
      | `Relative of Relative.t
      ]

    let with_ t ~f =
      match t with
      | `Absolute absolute -> f.f absolute
      | `Relative relative -> f.f relative
    ;;
  end

  let with_filename filename ~f = of_filename filename |> Either.with_ ~f
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
end
