open! Alice_stdlib

type t

val to_dyn : t -> Dyn.t
val of_package_with_deps : (_, _) Alice_package.Dependency_graph.Package_with_deps.t -> t
val source_code : t -> string
