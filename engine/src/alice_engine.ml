open! Alice_stdlib

module Target = struct
  type t = Filename.t

  let equal = Filename.equal

  module Map = Filename.Map
end

module Action = struct
  type t = Command.t
end

module Concrete_rule = struct
  type t =
    { output : Target.t
    ; inputs : Target.t list
    ; actions : Action.t list
    }
end

module Abstract_rule = struct
  type t = Target.t -> Concrete_rule.t option

  let create ~f output =
    f output
    |> Option.map ~f:(fun (`Inputs inputs, `Actions actions) ->
      { Concrete_rule.output; inputs; actions })
  ;;

  let create_fixed_output output ~inputs ~actions =
    create ~f:(fun target ->
      if Filename.equal target output
      then Some (`Inputs inputs, `Actions actions)
      else None)
  ;;

  let match_ t ~target = t target
end

module Abstract_rule_database = struct
  type t = Abstract_rule.t list

  let find t ~target =
    match List.find_map t ~f:(Abstract_rule.match_ ~target) with
    | Some concrete_rule -> concrete_rule
    | None -> failwith (Printf.sprintf "No rule to create file: %s" target)
  ;;
end

module Build_plan = struct
  (* Map targets to the rules that will produce them. *)
  type t = Concrete_rule.t Target.Map.t
end
