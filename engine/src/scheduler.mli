open! Alice_stdlib
open Alice_package

module Sequential : sig
  val eval_build_plans
    :  Build_graph.Build_plan.t list
    -> Package.t
    -> Alice_env.Env.t
    -> Profile.t
    -> Build_dir.t
    -> dep_libs:Package.Typed.lib_only_t list
    -> ocamlopt:Alice_which.Ocamlopt.t
    -> unit
end
