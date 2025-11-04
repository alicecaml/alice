open! Alice_stdlib
open Alice_package

module Sequential : sig
  val eval_build_plans
    :  Build_graph.Build_plan.t list
    -> (_, _) Dependency_graph.Package_with_deps.t
    -> Alice_env.Env.t
    -> Profile.t
    -> Build_dir.t
    -> Alice_which.Ocaml_compiler.t
    -> unit
end
