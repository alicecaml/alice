open! Alice_stdlib

type string_graph = String.Set.t String.Map.t

let dot_src_of_string_graph string_graph =
  let lines =
    String.Map.to_list string_graph
    |> List.map ~f:(fun (name, deps) ->
      let deps_str =
        String.Set.to_list deps |> List.map ~f:(sprintf "%S") |> String.concat ~sep:", "
      in
      sprintf "  \"%s\" -> {%s}" name deps_str)
  in
  String.concat ~sep:"\n" lines |> sprintf "digraph {\n%s\n}"
;;
