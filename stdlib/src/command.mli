type t =
  { prog : string
  ; args : string list
  }

val create : string -> args:string list -> t
val to_dyn : t -> Dyn.t
val to_string : t -> string
val to_string_backticks : t -> string
