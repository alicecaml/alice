type t =
  { prog : string
  ; args : string list
  ; env : Env.t
  }

val create : string -> args:string list -> Env.t -> t
val equal : t -> t -> bool
val to_dyn : t -> Dyn.t
val to_string_ignore_env : t -> string
val to_string_ignore_env_backticks : t -> string
