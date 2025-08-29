open! Alice_stdlib

val set_mode : [ `Standard | `Quiet ] -> unit

type message

val print : message -> unit
val println : message -> unit
val print_newline : unit -> unit

module Styles : sig
  val success : Ansi_style.t
end

val raw_message : ?style:Ansi_style.t -> string -> message

type verb =
  [ `Fetching
  | `Unpacking
  | `Compiling
  | `Running
  | `Creating
  ]

val verb_message : ?verb_style:Ansi_style.t -> verb -> string -> message
val done_message : ?style:Ansi_style.t -> unit -> message
