open! Alice_stdlib

module Build = struct
  type t =
    { inputs : Filename.Set.t
    ; commands : Command.t list
    }

  let to_dyn { inputs; commands } =
    Dyn.record
      [ "inputs", Filename.Set.to_dyn inputs
      ; "commands", Dyn.list Command.to_dyn commands
      ]
  ;;

  let equal t { inputs; commands } =
    Filename.Set.equal t.inputs inputs && List.equal ~eq:Command.equal t.commands commands
  ;;
end

module Origin = struct
  type t =
    | Source
    | Build of Build.t

  let to_dyn = function
    | Source -> Dyn.variant "Source" []
    | Build build -> Dyn.variant "Build" [ Build.to_dyn build ]
  ;;

  let equal a b =
    match a, b with
    | Source, Source -> true
    | Build a, Build b -> Build.equal a b
    | _, _ -> false
  ;;

  let inputs = function
    | Source -> Filename.Set.empty
    | Build build -> build.inputs
  ;;
end

type t = Origin.t Filename.Map.t

let to_dyn = Filename.Map.to_dyn Origin.to_dyn
let empty = Filename.Map.empty

module Staging = struct
  type nonrec t = t

  let to_dyn = to_dyn
  let empty = empty

  let add_origin t ~output ~origin =
    Filename.Map.update t ~key:output ~f:(function
      | None -> Some origin
      | Some existing ->
        if Origin.equal existing origin
        then Some existing
        else Alice_error.panic [ Pp.textf "Conflicting origins for file: %s" output ])
  ;;

  (* Returns any filename which is an input for some file but which is not a
     key in the map. *)
  let find_dangling_node t =
    Filename.Map.to_list t
    |> List.find_map ~f:(fun (_node, origin) ->
      match (origin : Origin.t) with
      | Source -> None
      | Build { inputs; _ } ->
        Filename.Set.to_list inputs
        |> List.find_opt ~f:(fun input -> not (Filename.Map.mem input t)))
  ;;

  (* Returns all the files that are not listed in the inputs for generating any
     other files. *)
  let find_roots t =
    let all_files = Filename.Map.keys t |> Filename.Set.of_list in
    Filename.Map.fold t ~init:all_files ~f:(fun ~key:_ ~data acc ->
      match (data : Origin.t) with
      | Source -> acc
      | Build build -> Filename.Set.diff acc build.inputs)
  ;;

  (* Returns any cycle from the graph, if one exists. *)
  let get_cycle t =
    let rec loop node seen path =
      match (Filename.Map.find node t : Origin.t) with
      | Source -> None
      | Build { Build.inputs; _ } ->
        if Filename.Set.mem node seen
        then Some path
        else (
          let seen = Filename.Set.add node seen in
          let inputs = Filename.Set.to_list inputs in
          List.find_map inputs ~f:(fun input -> loop input seen (node :: path)))
    in
    let roots = find_roots t |> Filename.Set.to_list in
    List.find_map roots ~f:(fun root -> loop root Filename.Set.empty [])
  ;;

  let finalize t =
    (match find_dangling_node t with
     | None -> ()
     | Some dangling -> Alice_error.panic [ Pp.textf "No rule to build: %s" dangling ]);
    (match get_cycle t with
     | None -> ()
     | Some cycle ->
       Alice_error.panic
         ([ Pp.text "Dependency cycle:"; Pp.newline ]
          @ List.concat_map cycle ~f:(fun file -> [ Pp.textf " - %s" file; Pp.newline ])));
    t
  ;;
end
