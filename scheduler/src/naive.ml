open! Alice_stdlib
module Build_plan = Alice_engine.Build_plan
module Traverse = Alice_engine.Build_plan.Traverse

let rec run traverse =
  let output = Traverse.output traverse in
  match (Traverse.origin traverse : Build_plan.Origin.t) with
  | Source -> print_endline (sprintf "source %s" output)
  | Build (build : Build_plan.Build.t) ->
    List.iter (Traverse.deps traverse) ~f:run;
    print_endline (sprintf "build %s" output)
;;
