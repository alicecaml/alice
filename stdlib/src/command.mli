type t =
  { prog : string
  ; args : string list
  }

val create : string -> args:string list -> t
val equal : t -> t -> bool
val to_dyn : t -> Dyn.t
val to_string : t -> string
val to_string_backticks : t -> string
