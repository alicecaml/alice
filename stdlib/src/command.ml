type t =
  { prog : string
  ; args : string list
  }

let create prog ~args = { prog; args }

let to_dyn { prog; args } =
  Dyn.record [ "prog", Dyn.string prog; "args", Dyn.list Dyn.string args ]
;;
