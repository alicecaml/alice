open! Alice_stdlib
module Path = Alice_hierarchy.Path.Relative
module Build = Build_plan.Build
module Origin = Build_plan.Origin

type t =
  | Dynamic of (Path.t -> Build_plan.Build.t option)
  | Static of Build.t

let to_dyn = function
  | Dynamic f -> Dyn.variant "Dynamic" [ Dyn.opaque f ]
  | Static build -> Dyn.variant "Static" [ Build.to_dyn build ]
;;

let dynamic ~f = Dynamic f
let static build = Static build

let match_ t ~output =
  match t with
  | Dynamic f -> f output
  | Static build -> if Path.Set.mem output build.outputs then Some build else None
;;

module Database = struct
  type nonrec t = t list

  let build_for_output_file_opt t ~output = List.find_map t ~f:(match_ ~output)

  let create_build_plan t ~outputs =
    let rec loop output acc =
      let origin =
        match (build_for_output_file_opt t ~output : Build.t option) with
        | None -> Origin.Source output
        | Some build -> Origin.Build build
      in
      let acc = Build_plan.Staging.add_origin acc origin in
      Origin.inputs origin |> Path.Set.fold ~init:acc ~f:loop
    in
    let staged =
      List.fold_left outputs ~init:Build_plan.Staging.empty ~f:(fun acc output ->
        loop output acc)
    in
    Build_plan.Staging.finalize staged
  ;;
end
