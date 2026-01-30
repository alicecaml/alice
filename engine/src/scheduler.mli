open! Alice_stdlib
open Alice_package
open Alice_ocaml_compiler

module Package_built : sig
  type t

  val any_rebuilt : t list -> bool
end

(** Evaluate a list of build plans for a single package. There may be
    multiple build plans for a package, such as if there's a library and
    executable to build. Build plans are evaluated in order. *)
val eval_build_plans
  :  _ Alice_io.Io_ctx.t
  -> Build_graph.Build_plan.t list
  -> (_, _) Dependency_graph.Package_with_deps.t
  -> Profile.t
  -> Build_dir.t
  -> Ocaml_compiler.t
  -> any_dep_rebuilt:bool
  -> Package_built.t
