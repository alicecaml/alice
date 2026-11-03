open! Alice_stdlib
open Alice_hierarchy
open Alice_package_meta

val set_mode : [ `Standard | `Quiet ] -> unit

(** Indicate that when converting paths to strings with this module's
    [path_to_string] function, separate path components with "/" rather than
    the current system's path separator. *)
val set_normalized_paths : unit -> unit

val set_hide_time : unit -> unit
val show_time : unit -> [ `Show_time | `Hide_time ]

type message

val print : message -> unit
val println : message -> unit

(** Returns a thunk that prints a message the first time it's called. *)
val println_once : message -> unit -> unit

val print_newline : unit -> unit

module Styles : sig
  val success : Ansi_style.t
end

val absolute_path_to_string : _ Absolute_path.t -> string
val basename_to_string : Basename.t -> string
val raw_message : ?style:Ansi_style.t -> string -> message

type verb =
  [ `Fetching
  | `Unpacking
  | `Building
  | `Running
  | `Creating
  | `Removing
  | `Built
  ]

val verb_message : ?verb_style:Ansi_style.t -> verb -> string -> message

val package_message
  :  ?verb_style:Ansi_style.t
  -> ?pre:Ansi_style.t Pp.t list
  -> ?post:Ansi_style.t Pp.t list
  -> verb
  -> Package_id.t
  -> message

val config_script_message_begin : Package_id.t -> message
val config_script_message_line : string -> message
val config_script_message_end : Package_id.t -> message
