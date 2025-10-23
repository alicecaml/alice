open! Alice_stdlib

module type Node = sig
  module Name : sig
    type t

    module Set : Set.S with type elt = t
    module Map : Map.S with type key = t
  end

  type t

  val to_dyn : t -> Dyn.t
  val equal : t -> t -> bool
  val dep_names : t -> Name.Set.t
  val show : t -> string
end

module Make (Node : Node) = struct
  type t = Node.t Node.Name.Map.t

  let empty = Node.Name.Map.empty
  let to_dyn = Node.Name.Map.to_dyn Node.to_dyn
  let nodes = Node.Name.Map.values

  let dot t =
    let lines =
      nodes t
      |> List.filter_map ~f:(fun node ->
        let dep_names = Node.dep_names node in
        if Node.Name.Set.is_empty dep_names
        then None
        else (
          let deps_str =
            Node.Name.Set.to_list dep_names
            |> List.map ~f:(fun dep_name ->
              let dep_node = Node.Name.Map.find dep_name t in
              sprintf "\"%s\"" (Node.show dep_node))
            |> String.concat ~sep:", "
          in
          Some (sprintf "  \"%s\" -> {%s}" (Node.show node) deps_str)))
      |> List.sort ~cmp:String.compare
    in
    String.concat ~sep:"\n" lines |> sprintf "digraph {\n%s\n}"
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
    Node.Name.Map.find_opt name t
    |> Option.map ~f:(fun node -> { Traverse.node; dag = t })
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
end
