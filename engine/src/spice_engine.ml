open! Spice_stdlib

module Target = struct
  type t = Filename.t
end

module Command = struct
  type t =
    { prog : string
    ; args : string list
    }

  let create prog ~args = { prog; args }
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

  let create ~f =
    fun output ->
    f output
    |> Option.map ~f:(fun (`Inputs inputs, `Actions actions) ->
      { Concrete_rule.output; inputs; actions })
  ;;

  let identity = create ~f:(fun output -> Some (`Inputs [ output ], `Actions []))
  let match_ t ~target = t target
end
