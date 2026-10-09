open! Alice_stdlib
open Alice_hierarchy

val set_mode : [ `Standard | `Quiet ] -> unit

(** Indicate that when converting paths to strings with this module's
    [path_to_string] function, separate path components with "/" rather than
    the current system's path separator. *)
val set_normalized_paths : unit -> unit

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
  | `Compiling
  | `Running
  | `Creating
  | `Removing
  | `Finished
  ]

val verb_message : ?verb_style:Ansi_style.t -> verb -> string -> message
val done_message : ?style:Ansi_style.t -> unit -> message
