open! Alice_stdlib

module Path = struct
  type absolute = |
  type relative = |

  type _ t =
    | Absolute : Filename.t -> absolute t
    | Relative : Filename.t -> relative t

  type 'a with_path = { f : 'kind. 'kind t -> 'a }

  let to_dyn : type a. a t -> Dyn.t = function
    | Absolute filename -> Dyn.variant "Absolute" [ Filename.to_dyn filename ]
    | Relative filename -> Dyn.variant "Relative" [ Filename.to_dyn filename ]
  ;;

  let of_filename filename =
    if Filename.is_relative filename
    then `Relative (Relative filename)
    else `Absolute (Absolute filename)
  ;;

  let to_filename : type a. a t -> Filename.t = function
    | Absolute filename -> filename
    | Relative filename -> filename
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

  module Absolute = struct
    type nonrec t = absolute t

    let getcwd () =
      let cwd = Unix.getcwd () in
      if Filename.is_relative cwd
      then
        Alice_error.panic
          [ Pp.textf "Current working directory is not absolute path: %s" cwd ];
      Absolute cwd
    ;;
  end

  module Relative = struct
    type nonrec t = relative t

    let to_absolute ~cwd t = concat cwd t
  end

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

    let to_absolute ~cwd = function
      | `Absolute absolute -> absolute
      | `Relative relative -> Relative.to_absolute relative ~cwd
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
end

module Dir = struct
  type 'path_kind t = 'path_kind File.dir =
    { path : 'path_kind Path.t
    ; contents : 'path_kind File.t list
    }

  let to_dyn = File.dir_to_dyn
end
