open! Alice_stdlib

module type Node = sig
  module Name : sig
    type t

    val to_dyn : t -> Dyn.t

    module Set : Set.S with type elt = t
    module Map : Map.S with type key = t
  end

  type t

  val to_dyn : t -> Dyn.t
  val equal : t -> t -> bool
  val name : t -> Name.t
  val dep_names : t -> Name.Set.t
  val show : t -> string
end

module Make (Node : Node) = struct
  type t = Node.t Node.Name.Map.t

  let empty = Node.Name.Map.empty
  let to_dyn = Node.Name.Map.to_dyn Node.to_dyn
  let nodes = Node.Name.Map.values

  let roots t =
    Node.Name.Map.fold t ~init:t ~f:(fun ~key:_ ~data acc ->
      Node.Name.Set.fold (Node.dep_names data) ~init:acc ~f:(fun name acc ->
        Node.Name.Map.remove name acc))
    |> Node.Name.Map.values
  ;;

  let to_string_graph t =
    Node.Name.Map.values t
    |> List.filter_map ~f:(fun node ->
      let dep_names = Node.dep_names node in
      if Node.Name.Set.is_empty dep_names
      then None
      else (
        let value =
          Node.Name.Set.to_list dep_names
          |> List.map ~f:(fun name -> Node.Name.Map.find name t |> Node.show)
          |> String.Set.of_list
        in
        let key = Node.show node in
        Some (key, value)))
    |> String.Map.of_list_exn
  ;;

  let transitive_closure_in_dependency_order t ~starts =
    let rec loop node seen acc =
      let unseen_deps = Node.Name.Set.diff (Node.dep_names node) seen in
      let seen, acc = loop_multi unseen_deps seen acc in
      Node.Name.Set.add (Node.name node) seen, node :: acc
    and loop_multi names seen acc =
      Node.Name.Set.fold names ~init:(seen, acc) ~f:(fun name (seen, acc) ->
        let node = Node.Name.Map.find name t in
        loop node seen acc)
    in
    loop_multi (Node.Name.Set.of_list starts) Node.Name.Set.empty [] |> snd |> List.rev
  ;;

  let all_nodes_in_dependency_order t =
    let starts = List.map (roots t) ~f:Node.name in
    transitive_closure_in_dependency_order t ~starts
  ;;

  module Traverse = struct
    type nonrec t =
      { node : Node.t
      ; dag : t
      }

    let node t = t.node

    let deps t =
      Node.dep_names t.node
      |> Node.Name.Set.to_list
      |> List.map ~f:(fun name ->
        let node = Node.Name.Map.find name t.dag in
        { t with node })
    ;;
  end

  let traverse t ~name =
    match Node.Name.Map.find_opt name t with
    | Some node -> { Traverse.node; dag = t }
    | None ->
      Alice_error.panic
        [ Pp.textf "No such node in this DAG: %s" (Node.Name.to_dyn name |> Dyn.to_string)
        ]
  ;;

  module Staging = struct
    type nonrec t = t

    let to_dyn = to_dyn
    let empty = empty

    let add t name node =
      let exception Conflict of Node.t in
      match
        Node.Name.Map.update t ~key:name ~f:(function
          | None -> Some node
          | Some existing ->
            if Node.equal existing node then Some existing else raise (Conflict existing))
      with
      | t -> Ok t
      | exception Conflict existing -> Error (`Conflict existing)
    ;;

    (* Return any name which is a dep of some node but which is not a key in
       the map. A well-formed DAG should have no such name. *)
    let find_dangling_node t =
      Node.Name.Map.values t
      |> List.find_map ~f:(fun node ->
        Node.dep_names node
        |> Node.Name.Set.to_list
        |> List.find_opt ~f:(fun name -> not (Node.Name.Map.mem name t)))
    ;;

    (* Find all the names which are not deps of any node. *)
    let find_roots t =
      let all_names = Node.Name.Map.keys t |> Node.Name.Set.of_list in
      Node.Name.Map.fold t ~init:all_names ~f:(fun ~key:_ ~data acc ->
        Node.Name.Set.diff acc (Node.dep_names data))
    ;;

    (* Returns any cycle from the graph, if one exists. *)
    let get_cycle t =
      let rec loop name seen path =
        let node = Node.Name.Map.find name t in
        if Node.Name.Set.mem name seen
        then Some path
        else (
          let seen = Node.Name.Set.add name seen in
          let deps = Node.dep_names node |> Node.Name.Set.to_list in
          List.find_map deps ~f:(fun dep -> loop dep seen (name :: path)))
      in
      let roots = find_roots t |> Node.Name.Set.to_list in
      List.find_map roots ~f:(fun root -> loop root Node.Name.Set.empty [])
    ;;

    let finalize t =
      match find_dangling_node t with
      | Some dangling -> Error (`Dangling dangling)
      | None ->
        (match get_cycle t with
         | Some cycle -> Error (`Cycle cycle)
         | None -> Ok t)
    ;;
  end

  let restage t = t
end
