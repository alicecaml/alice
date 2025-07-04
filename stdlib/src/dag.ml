module type Name = sig
  type t

  val equal : t -> t -> bool
  val to_dyn : t -> Dyn.t

  module Set : Set.S with type elt = t
  module Map : Map.S with type key = t
end

module type S = sig
  type name
  type 'a node
  type 'a t

  val to_dyn : 'a Dyn.builder -> 'a t -> Dyn.t
  val empty : 'a t
  val add_node : 'a t -> name:name -> value:'a -> 'a t

  val add_edge
    :  'a t
    -> from:name
    -> to_:name
    -> ('a t, [ `Would_create_cycle_through of name list ]) result
end

module Make (Name : Name) = struct
  module Node = struct
    type 'a t =
      { neighbours : Name.Set.t
      ; value : 'a
      }

    let to_dyn f { neighbours; value } =
      Dyn.record [ "neighbours", Name.Set.to_dyn neighbours; "value", f value ]
    ;;
  end

  type name = Name.t
  type 'a node = 'a Node.t

  (* Node A connects to node B iff the map contains an association from A to a
     set containing B. A graph is valid if all nodes present in the graph are
     keys of the map, even if they don't connect to any other nodes (in which
     case their associated set will be empty). This module also maintains the
     invariant that the graph does not contain cycles. *)
  type 'a t = 'a Node.t Name.Map.t

  let to_dyn f = Name.Map.to_dyn (Node.to_dyn f)
  let empty = Name.Map.empty

  let add_node t ~name ~value =
    Name.Map.update t ~key:name ~f:(function
      | None -> Some { Node.value; neighbours = Name.Set.empty }
      | Some _ ->
        failwith
          (Printf.sprintf
             "Tried to add multiple nodes with the same name: %s"
             (Name.to_dyn name |> Dyn.to_string)))
  ;;

  (* This function relies on the fact that the graph has no cycles. If this is
     called on a graph with cycles then it may loop forever or overflow its
     stack. Returns the sequence of nodes leading from [src] to [dst] or [None]
     if no such sequence exists.*)
  let get_path t ~src ~dst =
    let rec loop node acc =
      if Name.equal node dst
      then Some acc
      else (
        match Name.Map.find_opt node t with
        | None -> failwith "get_path called on invalid graph"
        | Some (node : 'a Node.t) ->
          Name.Set.to_list node.neighbours
          |> List.find_map ~f:(fun node -> loop node (node :: acc)))
    in
    loop src []
  ;;

  let add_edge t ~from ~to_ =
    let would_create_cycle_through = ref None in
    if not (Name.Map.mem to_ t)
    then
      failwith
        (Printf.sprintf
           "No node found for \"to\" side of edge: %s"
           (Name.to_dyn to_ |> Dyn.to_string));
    let t' =
      Name.Map.update t ~key:from ~f:(function
        | None ->
          failwith
            (Printf.sprintf
               "No node found for \"from\" side of edge: %s"
               (Name.to_dyn from |> Dyn.to_string))
        | Some (node : 'a Node.t) ->
          if Name.Set.mem to_ node.neighbours
          then
            (* The graph already has this edge. *)
            Some node
          else (
            match get_path t ~src:to_ ~dst:from with
            | None -> Some { node with neighbours = Name.Set.add to_ node.neighbours }
            | Some path ->
              would_create_cycle_through := Some path;
              Some node))
    in
    match !would_create_cycle_through with
    | Some cycle -> Error (`Would_create_cycle_through cycle)
    | None -> Ok t'
  ;;
end
