open! Alice_stdlib

module type Name = sig
  type t

  val to_dyn : t -> Dyn.t
  val equal : t -> t -> bool
  val to_string : t -> string

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
      ; mutable children_by_name : 'a t Name.Map.t
      ; mutable parents_by_name : 'a t Name.Map.t
      }

    let to_dyn
          builder
          { name
          ; value
          ; child_names
          ; children
          ; parents
          ; children_by_name
          ; parents_by_name
          }
      =
      Dyn.record
        [ "name", Name.to_dyn name
        ; "value", builder value
        ; "child_names", Dyn.list Name.to_dyn child_names
        ; "children", Dyn.opaque children
        ; "parents", Dyn.opaque parents
        ; "children_by_name", Dyn.opaque children_by_name
        ; "parents_by_name", Dyn.opaque parents_by_name
        ]
    ;;

    let name t = t.name
    let value t = t.value
    let children t = t.children

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
    { nodes_by_name : 'a Node.t Name.Map.t
    ; roots : 'a Node.t list
    }

  let to_dyn builder { nodes_by_name; roots } =
    Dyn.record
      [ "nodes_by_name", Name.Map.to_dyn (Node.to_dyn builder) nodes_by_name
      ; "roots", Dyn.list (Node.to_dyn builder) roots
      ]
  ;;

  let roots t = t.roots
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

  let all_nodes t = Name.Map.values t.nodes_by_name

  let all_nodes_in_child_first_order t =
    match Nonempty_list.of_list_opt t.roots with
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
              (Name.to_string name)
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
      let nodes_by_name =
        Name.Map.map t ~f:(fun (staging_node : _ Staging_node.t) ->
          { Node.name = staging_node.name
          ; value = staging_node.value
          ; child_names = staging_node.child_names
          ; children = []
          ; parents = []
          ; children_by_name = Name.Map.empty
          ; parents_by_name = Name.Map.empty
          })
      in
      let get_node name = Name.Map.find name nodes_by_name in
      Name.Map.iter nodes_by_name ~f:(fun ~key:node_name ~data:(node : _ Node.t) ->
        List.iter node.child_names ~f:(fun child_name ->
          let child_node = get_node child_name in
          node.children_by_name
          <- Name.Map.add node.children_by_name ~key:child_name ~data:child_node;
          child_node.parents_by_name
          <- Name.Map.add child_node.parents_by_name ~key:node_name ~data:node));
      Name.Map.iter nodes_by_name ~f:(fun ~key:_ ~data:(node : _ Node.t) ->
        node.children <- Name.Map.values node.children_by_name;
        node.parents <- Name.Map.values node.parents_by_name);
      let root_names = find_roots t in
      let roots = Name.Set.to_list root_names |> List.map ~f:get_node in
      { nodes_by_name; roots }
    ;;

    let finalize_or_panic t =
      match finalize t with
      | Ok t -> t
      | Error (`Dangling dangling) ->
        Alice_error.panic [ Pp.textf "No node with name: %s" (Name.to_string dangling) ]
      | Error (`Cycle cycle) ->
        Alice_error.panic
          ([ Pp.text "DAG would contain cycle:"; Pp.newline ]
           @ List.concat_map cycle ~f:(fun name ->
             [ Pp.textf " - %s" (Name.to_string name); Pp.newline ]))
    ;;
  end

  let node_to_staging_node (node : _ Node.t) =
    { Staging.Staging_node.name = node.name
    ; value = node.value
    ; child_names = node.child_names
    }
  ;;

  let restage t = Name.Map.map t.nodes_by_name ~f:node_to_staging_node
end
