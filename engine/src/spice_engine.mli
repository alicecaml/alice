open! Spice_stdlib

module Target : sig
  type t = Filename.t
end

module Command : sig
  type t =
    { prog : string
    ; args : string list
    }

  val create : string -> args:string list -> t
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
  val identity : t
  val match_ : t -> target:Target.t -> Concrete_rule.t option
end
