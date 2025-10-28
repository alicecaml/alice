open! Alice_stdlib
open Alice_hierarchy

type t =
  | Dynamic of (Path.Relative.t -> Origin.Build.t option)
  | Static of Origin.Build.t

let to_dyn = function
  | Dynamic f -> Dyn.variant "Dynamic" [ Dyn.opaque f ]
  | Static build -> Dyn.variant "Static" [ Origin.Build.to_dyn build ]
;;

let dynamic ~f = Dynamic f
let static build = Static build

let match_ t ~output =
  match t with
  | Dynamic f -> f output
  | Static build ->
    if Path.Relative.Set.mem output build.outputs then Some build else None
;;

module Database = struct
  type nonrec t = t list

  let build_for_output_file_opt t ~output = List.find_map t ~f:(match_ ~output)

  let create_build_graph t ~outputs =
    let rec loop output acc =
      let origin =
        match (build_for_output_file_opt t ~output : Origin.Build.t option) with
        | None -> Origin.Source output
        | Some build -> Origin.Build build
      in
      let acc = Build_graph.Staging.add_origin acc origin in
      Origin.inputs origin |> Path.Relative.Set.fold ~init:acc ~f:loop
    in
    let staged =
      List.fold_left outputs ~init:Build_graph.Staging.empty ~f:(fun acc output ->
        loop output acc)
    in
    Build_graph.Staging.finalize staged
  ;;
end
