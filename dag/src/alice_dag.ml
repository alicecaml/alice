open! Alice_stdlib

module type Name = sig
  type t

  val to_dyn : t -> Dyn.t
  val equal : t -> t -> bool

  module Set : Set.S with type elt = t
  module Map : Map.S with type key = t
end

module Make (Name : Name) = struct
  module Node = struct
    type 'a t =
      { name : Name.t
      ; value : 'a
      ; child_names : Name.t list
      ; mutable children : 'a t list
      ; mutable parents : 'a t list
      }

    let equal t { name; value; child_names; children = _; parents = _ } ~eq =
      Name.equal t.name name
      && eq t.value value
      && List.equal ~eq:Name.equal t.child_names child_names
    ;;

    let to_dyn builder { name; value; child_names; children; parents } =
      Dyn.record
        [ "name", Name.to_dyn name
        ; "value", builder value
        ; "child_names", Dyn.list Name.to_dyn child_names
        ; "children", Dyn.opaque children
        ; "parents", Dyn.opaque parents
        ]
    ;;

    let name t = t.name
    let value t = t.value
    let children t = t.children
    let parents t = t.parents

    (* Takes multiple start nodes and returns the transitive closure in an order
       such that nodes preceed their children. *)
    let transitive_closure_multi_in_parent_first_order ts =
      let rec loop t seen acc =
        if Name.Set.mem t.name seen
        then seen, acc
        else (
          let seen, acc = loop_multi t.children seen acc in
          let seen = Name.Set.add t.name seen in
          let acc = t :: acc in
          seen, acc)
      and loop_multi nodes seen acc =
        List.fold_left nodes ~init:(seen, acc) ~f:(fun (seen, acc) node ->
          loop node seen acc)
      in
      let starts = Nonempty_list.to_list ts in
      match loop_multi starts Name.Set.empty [] |> snd with
      | [] -> failwith "unreachable"
      | x :: xs -> Nonempty_list.(x :: xs)
    ;;

    let transitive_closure_in_child_first_order t ~include_start =
      let (x :: xs) =
        transitive_closure_multi_in_parent_first_order (Nonempty_list.singleton t)
      in
      List.rev (if include_start then x :: xs else xs)
    ;;
  end

  type 'a t =
    { nodes : 'a Node.t array
    ; nodes_by_name : 'a Node.t Name.Map.t
    }

  let to_dyn builder { nodes; nodes_by_name } =
    Dyn.record
      [ "nodes", Dyn.array (Node.to_dyn builder) nodes
      ; "nodes_by_name", Name.Map.to_dyn (Node.to_dyn builder) nodes_by_name
      ]
  ;;

  let roots t =
    Array.to_seq t.nodes
    |> Seq.filter ~f:(fun node -> List.is_empty (Node.parents node))
    |> List.of_seq
  ;;

  let leaves t =
    Array.to_seq t.nodes
    |> Seq.filter ~f:(fun node -> List.is_empty (Node.children node))
    |> List.of_seq
  ;;

  let get_node t ~name = Name.Map.find name t.nodes_by_name

  let to_string_graph t ~node_to_string =
    Name.Map.values t.nodes_by_name
    |> List.filter_map ~f:(fun (node : _ Node.t) ->
      if List.is_empty node.children
      then None
      else (
        let value =
          List.map node.children ~f:(fun (child : _ Node.t) -> node_to_string child)
          |> String.Set.of_list
        in
        let key = node_to_string node in
        Some (key, value)))
    |> String.Map.of_list_exn
  ;;

  let all_nodes t = Array.to_list t.nodes
  let all_names t = Name.Map.keys t.nodes_by_name

  let all_nodes_in_child_first_order t =
    match Nonempty_list.of_list_opt (roots t) with
    | None -> []
    | Some roots ->
      Node.transitive_closure_multi_in_parent_first_order roots
      |> Nonempty_list.to_list
      |> List.rev
  ;;

  module Staging = struct
    module Staging_node = struct
      type 'a t =
        { name : Name.t
        ; value : 'a
        ; child_names : Name.t list
        }

      let equal t ~eq { name; value; child_names } =
        Name.equal t.name name
        && eq t.value value
        && List.equal ~eq:Name.equal t.child_names child_names
      ;;
    end

    type 'a t = 'a Staging_node.t Name.Map.t

    let empty = Name.Map.empty

    let add t name value ~eq ~child_names =
      let exception Conflict in
      let node = { Staging_node.name; value; child_names } in
      match
        Name.Map.update t ~key:name ~f:(function
          | None -> Some node
          | Some existing ->
            if Staging_node.equal ~eq existing node then Some existing else raise Conflict)
      with
      | t -> Ok t
      | exception Conflict -> Error `Conflict
    ;;

    let add_or_panic t name value ~eq ~child_names =
      match add t name value ~eq ~child_names with
      | Ok t -> t
      | Error `Conflict ->
        Alice_error.panic
          [ Pp.textf
              "DAG already contains node named %S with different value."
              (Name.to_dyn name |> Dyn.to_string)
          ]
    ;;

    (* Return any name which is a child of some node but which is not a key in
       the map. A well-formed DAG should have no such name. *)
    let find_dangling_node t =
      Name.Map.values t
      |> List.find_map ~f:(fun (node : _ Staging_node.t) ->
        List.find_opt node.child_names ~f:(fun name -> not (Name.Map.mem name t)))
    ;;

    (* Find all the names which are not deps of any node. *)
    let find_roots t =
      let all_names = Name.Map.keys t |> Name.Set.of_list in
      Name.Map.fold t ~init:all_names ~f:(fun ~key:_ ~(data : _ Staging_node.t) acc ->
        let child_names = Name.Set.of_list data.child_names in
        Name.Set.diff acc child_names)
    ;;

    (* Returns any cycle from the graph, if one exists. *)
    let get_cycle (t : _ t) =
      let rec loop name seen path =
        let node = Name.Map.find name t in
        if Name.Set.mem name seen
        then Some path
        else (
          let seen = Name.Set.add name seen in
          List.find_map node.child_names ~f:(fun dep -> loop dep seen (name :: path)))
      in
      let roots = find_roots t |> Name.Set.to_list in
      List.find_map roots ~f:(fun root -> loop root Name.Set.empty [])
    ;;

    let validate t =
      match find_dangling_node t with
      | Some dangling -> Error (`Dangling dangling)
      | None ->
        (match get_cycle t with
         | Some cycle -> Error (`Cycle cycle)
         | None -> Ok ())
    ;;

    let finalize t =
      let open Result.O in
      let+ () = validate t in
      let nodes =
        Name.Map.to_seq t
        |> Seq.map ~f:(fun ((_, staging_node) : _ * _ Staging_node.t) ->
          { Node.name = staging_node.name
          ; value = staging_node.value
          ; child_names = staging_node.child_names
          ; children = []
          ; parents = []
          })
        |> Array.of_seq
      in
      let nodes_by_name =
        Array.to_seq nodes
        |> Seq.map ~f:(fun (node : _ Node.t) -> node.name, node)
        |> Name.Map.of_seq
      in
      let get_node name = Name.Map.find name nodes_by_name in
      Array.iter nodes ~f:(fun (node : _ Node.t) ->
        List.iter node.child_names ~f:(fun child_name ->
          let child_node = get_node child_name in
          node.children <- child_node :: node.children;
          child_node.parents <- node :: child_node.parents));
      { nodes; nodes_by_name }
    ;;

    let finalize_or_panic t =
      match finalize t with
      | Ok t -> t
      | Error (`Dangling dangling) ->
        Alice_error.panic
          [ Pp.textf
              "While finalizing DAG, no node with name: %s"
              (Name.to_dyn dangling |> Dyn.to_string)
          ]
      | Error (`Cycle cycle) ->
        Alice_error.panic
          ([ Pp.text "While finalizing DAG, DAG would contain cycle:"; Pp.newline ]
           @ List.concat_map cycle ~f:(fun name ->
             [ Pp.textf " - %s" (Name.to_dyn name |> Dyn.to_string); Pp.newline ]))
    ;;
  end
end
