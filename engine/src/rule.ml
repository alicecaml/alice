open! Alice_stdlib
module Build = Build_plan.Build
module Origin = Build_plan.Origin

type t = Filename.t -> Build_plan.Build.t option

let create ~f = f

let create_fixed_output ~output ~build =
  create ~f:(fun filename -> if Filename.equal filename output then Some build else None)
;;

let match_ t ~output = t output

module Database = struct
  type nonrec t = t list

  let build_for_output_file_opt t ~output = List.find_map t ~f:(match_ ~output)

  let create_build_plan t ~output =
    let rec loop output acc =
      let origin =
        match (build_for_output_file_opt t ~output : Build.t option) with
        | None -> Origin.Source
        | Some build -> Origin.Build build
      in
      let acc = Build_plan.Staging.add_origin acc ~output ~origin in
      Origin.inputs origin |> Filename.Set.fold ~init:acc ~f:loop
    in
    let staged = loop output Build_plan.Staging.empty in
    Build_plan.Staging.finalize staged
  ;;
end
