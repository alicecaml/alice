open! Alice_stdlib

module Target : sig
  type t = Filename.t
end

module Action : sig
  type t = Command.t
end

module Concrete_rule : sig
  type t =
    { output : Target.t
    ; inputs : Target.t list
    ; actions : Action.t list
    }
end

module Abstract_rule : sig
  type t
  type inputs := [ `Inputs of Target.t list ]
  type actions := [ `Actions of Action.t list ]

  val create : f:(Target.t -> (inputs * actions) option) -> t
  val create_fixed_output : Target.t -> inputs:Target.t list -> actions:Action.t list -> t
  val match_ : t -> target:Target.t -> Concrete_rule.t option
end

module Abstract_rule_database : sig
  type t = Abstract_rule.t list

  val find : t -> target:Target.t -> Concrete_rule.t
end
