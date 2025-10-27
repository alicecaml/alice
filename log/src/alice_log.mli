open! Alice_stdlib

type level =
  [ `Debug
  | `Info
  | `Warn
  | `Error
  ]

type package := Alice_package_meta.Package_id.t

val set_level : level -> unit

(** The type of __POS__ (the current file position) for convenience passing the
    value of __POS__ to logging functions. *)
type pos = string * int * int * int

val log : ?pos:pos -> ?package:package -> level:level -> Ansi_style.t Pp.t list -> unit
val debug : ?pos:pos -> ?package:package -> Ansi_style.t Pp.t list -> unit
val info : ?pos:pos -> ?package:package -> Ansi_style.t Pp.t list -> unit
val warn : ?pos:pos -> ?package:package -> Ansi_style.t Pp.t list -> unit
val error : ?pos:pos -> ?package:package -> Ansi_style.t Pp.t list -> unit
