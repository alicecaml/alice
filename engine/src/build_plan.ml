open! Alice_stdlib
module Path = Alice_hierarchy.Path.Relative

module Build = struct
  type t =
    { inputs : Path.Set.t
    ; outputs : Path.Set.t
    ; commands : Command.t list
    }

  let to_dyn { inputs; outputs; commands } =
    Dyn.record
      [ "inputs", Path.Set.to_dyn inputs
      ; "outputs", Path.Set.to_dyn outputs
      ; "commands", Dyn.list Command.to_dyn commands
      ]
  ;;

  let equal t { inputs; outputs; commands } =
    Path.Set.equal t.inputs inputs
    && Path.Set.equal t.outputs outputs
    && List.equal ~eq:Command.equal t.commands commands
  ;;
end

module Origin = struct
  type t =
    | Source of Path.t
    | Build of Build.t

  let to_dyn = function
    | Source path -> Dyn.variant "Source" [ Path.to_dyn path ]
    | Build build -> Dyn.variant "Build" [ Build.to_dyn build ]
  ;;

  let equal a b =
    match a, b with
    | Source a, Source b -> Path.equal a b
    | Build a, Build b -> Build.equal a b
    | _, _ -> false
  ;;

  let inputs = function
    | Source _ -> Path.Set.empty
    | Build build -> build.inputs
  ;;

  let outputs = function
    | Source path -> Path.Set.singleton path
    | Build build -> build.outputs
  ;;
end

type t = Origin.t Path.Map.t

let to_dyn = Path.Map.to_dyn Origin.to_dyn
let empty = Path.Map.empty

module Staging = struct
  type nonrec t = t

  let to_dyn = to_dyn
  let empty = empty

  let add_origin t origin =
    Path.Set.fold (Origin.outputs origin) ~init:t ~f:(fun output t ->
      Path.Map.update t ~key:output ~f:(function
        | None -> Some origin
        | Some existing ->
          if Origin.equal existing origin
          then Some existing
          else
            Alice_error.panic
              [ Pp.textf
                  "Conflicting origins for file: %s"
                  (Alice_ui.path_to_string output)
              ]))
  ;;

  (* Returns any filename which is an input for some file but which is not a
     key in the map. *)
  let find_dangling_node t =
    Path.Map.to_list t
    |> List.find_map ~f:(fun (_node, origin) ->
      match (origin : Origin.t) with
      | Source _ -> None
      | Build { inputs; _ } ->
        Path.Set.to_list inputs
        |> List.find_opt ~f:(fun input -> not (Path.Map.mem input t)))
  ;;

  (* Returns all the files that are not listed in the inputs for generating any
     other files. *)
  let find_roots t =
    let all_files = Path.Map.keys t |> Path.Set.of_list in
    Path.Map.fold t ~init:all_files ~f:(fun ~key:_ ~data acc ->
      match (data : Origin.t) with
      | Source _ -> acc
      | Build build -> Path.Set.diff acc build.inputs)
  ;;

  (* Returns any cycle from the graph, if one exists. *)
  let get_cycle t =
    let rec loop node seen path =
      match (Path.Map.find node t : Origin.t) with
      | Source _ -> None
      | Build { Build.inputs; _ } ->
        if Path.Set.mem node seen
        then Some path
        else (
          let seen = Path.Set.add node seen in
          let inputs = Path.Set.to_list inputs in
          List.find_map inputs ~f:(fun input -> loop input seen (node :: path)))
    in
    let roots = find_roots t |> Path.Set.to_list in
    List.find_map roots ~f:(fun root -> loop root Path.Set.empty [])
  ;;

  let finalize t =
    (match find_dangling_node t with
     | None -> ()
     | Some dangling ->
       Alice_error.panic
         [ Pp.textf "No rule to build: %s" (Alice_ui.path_to_string dangling) ]);
    (match get_cycle t with
     | None -> ()
     | Some cycle ->
       Alice_error.panic
         ([ Pp.text "Dependency cycle:"; Pp.newline ]
          @ List.concat_map cycle ~f:(fun file ->
            [ Pp.textf " - %s" (Alice_ui.path_to_string file); Pp.newline ])));
    t
  ;;
end

module Traverse = struct
  type nonrec t =
    { origin : Origin.t
    ; build_plan : t
    }

  let origin t = t.origin
  let outputs t = Origin.outputs t.origin

  let deps t =
    match (t.origin : Origin.t) with
    | Source _ -> []
    | Build { Build.inputs; _ } ->
      Path.Set.to_list inputs
      |> List.map ~f:(fun output ->
        let origin = Path.Map.find output t.build_plan in
        { t with origin })
  ;;
end

let traverse t ~output =
  Path.Map.find_opt output t
  |> Option.map ~f:(fun origin -> { Traverse.origin; build_plan = t })
;;

let dot t =
  let lines =
    Path.Map.to_list t
    |> List.filter_map ~f:(fun (output, (origin : Origin.t)) ->
      match origin with
      | Source _ -> None
      | Build { inputs; outputs = _; commands = _ } ->
        let inputs_str =
          Path.Set.to_list inputs
          |> List.map ~f:(fun path -> sprintf "\"%s\"" (Alice_ui.path_to_string path))
          |> String.concat ~sep:", "
        in
        Some (sprintf "  \"%s\" -> {%s}" (Alice_ui.path_to_string output) inputs_str))
    |> List.sort ~cmp:String.compare
  in
  String.concat ~sep:"\n" lines |> sprintf "digraph {\n%s\n}"
;;
