type t =
  { prog : string
  ; args : string list
  }

val create : string -> args:string list -> t
val to_dyn : t -> Dyn.t
