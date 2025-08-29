open! Alice_stdlib

let mode : [ `Standard | `Quiet ] ref = ref `Standard
let set_mode mode' = mode := mode'

type message = Ansi_style.t Pp.t list

let print pps =
  match !mode with
  | `Standard -> Raw.pps_print pps
  | `Quiet -> ()
;;

let println pps =
  match !mode with
  | `Standard -> Raw.pps_println pps
  | `Quiet -> ()
;;

let print_newline () = println []

module Styles = struct
  let success = Ansi_style.create ~bold:true ~color:`Green ()
end

let raw_message ?(style = Ansi_style.default) raw = [ Pp.text raw |> Pp.tag style ]
let default_verb_style = Ansi_style.create ~bold:true ~color:`Green ()

type verb =
  [ `Fetching
  | `Unpacking
  | `Compiling
  | `Running
  | `Creating
  ]

let verb_to_string_padded = function
  | `Fetching -> "  Fetching"
  | `Unpacking -> " Unpacking"
  | `Compiling -> " Compiling"
  | `Running -> "   Running"
  | `Creating -> "  Creating"
;;

let verb_message ?(verb_style = default_verb_style) verb object_ =
  [ Pp.text (verb_to_string_padded verb) |> Pp.tag verb_style; Pp.space; Pp.text object_ ]
;;

let default_done_style = Ansi_style.create ~bold:true ~color:`Green ()
let done_message ?(style = default_done_style) () = [ Pp.text "Done!" |> Pp.tag style ]
