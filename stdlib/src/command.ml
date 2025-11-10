type t =
  { prog : string
  ; args : string list
  ; env : Env.t
  }

let create prog ~args env = { prog; args; env }

let equal t { prog; args; env } =
  String.equal t.prog prog
  && List.equal ~eq:String.equal t.args args
  && Env.equal t.env env
;;

let to_dyn { prog; args; env } =
  Dyn.record
    [ "prog", Dyn.string prog; "args", Dyn.list Dyn.string args; "env", Env.to_dyn env ]
;;

let to_string_ignore_env { prog; args; env = _ } = String.concat ~sep:" " (prog :: args)

let to_string_ignore_env_backticks t =
  String.cat (String.cat "`" (to_string_ignore_env t)) "`"
;;
