open! Alice_stdlib
open Alice_package

module Package_built : sig
  type t

  val any_rebuilt : t list -> bool
end

module Sequential : sig
  val eval_build_plans
    :  Build_graph.Build_plan.t list
    -> (_, _) Dependency_graph.Package_with_deps.t
    -> Alice_env.Env.t
    -> Profile.t
    -> Build_dir.t
    -> Alice_which.Ocaml_compiler.t
    -> any_dep_rebuilt:bool
    -> Package_built.t
end
