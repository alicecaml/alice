open! Alice_stdlib

module type Node = sig
  type t
  type name

  module Name_set : Set.S with type elt = name
  module Name_map : Map.S with type key = name

  val to_dyn : t -> Dyn.t
  val equal : t -> t -> bool
  val deps : t -> Name_set.t
end

module Make (Node : Node) = struct
  module Name_map = Node.Name_map
  module Name_set = Node.Name_set

  type t = Node.t Name_map.t

  let empty = Name_map.empty
  let to_dyn = Name_map.to_dyn Node.to_dyn
  let to_list = Name_map.to_list

  module Traverse = struct
    type nonrec t =
      { node : Node.t
      ; dag : t
      }

    let node t = t.node

    let deps t =
      Node.deps t.node
      |> Name_set.to_list
      |> List.map ~f:(fun name ->
        let node = Name_map.find name t.dag in
        { t with node })
    ;;
  end

  let traverse t ~name =
    Name_map.find_opt name t |> Option.map ~f:(fun node -> { Traverse.node; dag = t })
  ;;

  module Staging = struct
    type nonrec t = t

    let to_dyn = to_dyn
    let empty = empty

    let add t name node =
      let exception Conflict of Node.t in
      match
        Name_map.update t ~key:name ~f:(function
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
      Name_map.values t
      |> List.find_map ~f:(fun node ->
        Node.deps node
        |> Name_set.to_list
        |> List.find_opt ~f:(fun name -> not (Name_map.mem name t)))
    ;;

    (* Find all the names which are not deps of any node. *)
    let find_roots t =
      let all_names = Name_map.keys t |> Name_set.of_list in
      Name_map.fold t ~init:all_names ~f:(fun ~key:_ ~data acc ->
        Name_set.diff acc (Node.deps data))
    ;;

    (* Returns any cycle from the graph, if one exists. *)
    let get_cycle t =
      let rec loop name seen path =
        let node = Name_map.find name t in
        if Name_set.mem name seen
        then Some path
        else (
          let seen = Name_set.add name seen in
          let deps = Node.deps node |> Name_set.to_list in
          List.find_map deps ~f:(fun dep -> loop dep seen (name :: path)))
      in
      let roots = find_roots t |> Name_set.to_list in
      List.find_map roots ~f:(fun root -> loop root Name_set.empty [])
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
