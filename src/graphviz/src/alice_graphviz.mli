open! Alice_stdlib

type string_graph = String.Set.t String.Map.t

val dot_src_of_string_graph : string_graph -> string
