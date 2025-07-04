open! Alice_stdlib

module File = struct
  type kind =
    | Regular
    | Link of Filename.t
    | Dir of t list
    | Unknown

  and t =
    { path : Filename.t
    ; kind : kind
    }

  let rec to_dyn { path; kind } =
    Dyn.record [ "path", Filename.to_dyn path; "kind", kind_to_dyn kind ]

  and kind_to_dyn = function
    | Regular -> Dyn.variant "Regular" []
    | Link dest -> Dyn.variant "Link" [ Filename.to_dyn dest ]
    | Dir contents -> Dyn.variant "Dir" [ Dyn.list to_dyn contents ]
    | Unknown -> Dyn.variant "Unknown" []
  ;;

  type dir =
    { path : Filename.t
    ; contents : t list
    }

  let dir_to_dyn { path; contents } =
    Dyn.record [ "path", Filename.to_dyn path; "contents", Dyn.list to_dyn contents ]
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
    | Regular | Link _ -> true
    | _ -> false
  ;;

  let rec traverse_bottom_up t ~f =
    match t.kind with
    | Regular | Link _ -> f t
    | Dir contents ->
      List.iter contents ~f:(traverse_bottom_up ~f);
      f t
    | Unknown -> ()
  ;;

  let rec traverse_top_down t ~f =
    match t.kind with
    | Regular | Link _ -> f t
    | Dir contents ->
      f t;
      List.iter contents ~f:(traverse_top_down ~f)
    | Unknown -> ()
  ;;
end

module Dir = struct
  type t = File.dir =
    { path : Filename.t
    ; contents : File.t list
    }

  let to_dyn = File.dir_to_dyn
end
