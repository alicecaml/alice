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

  module Dir = struct
    type nonrec t =
      { path : Filename.t
      ; contents : t list
      }
  end

  let as_dir { kind; path } =
    match kind with
    | Dir contents -> Some { Dir.path; contents }
    | _ -> None
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
end
