open! Alice_stdlib

type level =
  [ `Debug
  | `Info
  | `Warn
  | `Error
  ]

val set_level : level -> unit

(** The type of __POS__ (the current file position) for convenience passing the
    value of __POS__ to logging functions. *)
type pos = string * int * int * int

val log : ?pos:pos -> level:level -> Ansi_style.t Pp.t list -> unit
val debug : ?pos:pos -> Ansi_style.t Pp.t list -> unit
val info : ?pos:pos -> Ansi_style.t Pp.t list -> unit
val warn : ?pos:pos -> Ansi_style.t Pp.t list -> unit
val error : ?pos:pos -> Ansi_style.t Pp.t list -> unit
