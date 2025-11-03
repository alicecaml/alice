open! Alice_stdlib
open Alice_package

module Sequential : sig
  val eval_build_plans
    :  Build_graph.Build_plan.t list
    -> Package.t
    -> Profile.t
    -> Build_dir.t
    -> dep_libs:Package.Typed.lib_only_t list
    -> env:Alice_env.Env.t
    -> ocamlopt:Alice_which.Ocamlopt.t
    -> unit
end
