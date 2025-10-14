open! Alice_stdlib
open Alice_hierarchy
module Raw = Alice_print.Raw

let mode : [ `Standard | `Quiet ] ref = ref `Standard
let set_mode mode' = mode := mode'
let path_style : [ `Native | `Normalized ] ref = ref `Native
let set_normalized_paths () = path_style := `Normalized

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

let path_to_string path =
  match !path_style with
  | `Native -> Path.to_filename path
  | `Normalized ->
    let path =
      if Path.has_extension path ~ext:".exe" then Path.remove_extension path else path
    in
    let filename = Path.to_filename path in
    let normalize_filename filename =
      (* The start of the path will always be a period. Skip it. *)
      let (_current_dir :: components) = Filename.to_components filename in
      if List.is_empty components then "." else String.concat ~sep:"/" components
    in
    (match Path.to_either path with
     | `Relative _ -> normalize_filename filename
     | `Absolute path ->
       let path = Path.chop_prefix path ~prefix:(Path.absolute (Sys.getcwd ())) in
       let filename = Path.to_filename path in
       normalize_filename filename)
;;

let raw_message ?(style = Ansi_style.default) raw = [ Pp.text raw |> Pp.tag style ]
let default_verb_style = Ansi_style.create ~bold:true ~color:`Green ()

type verb =
  [ `Fetching
  | `Unpacking
  | `Compiling
  | `Running
  | `Creating
  | `Removing
  ]

let verb_to_string_padded = function
  | `Fetching -> "  Fetching"
  | `Unpacking -> " Unpacking"
  | `Compiling -> " Compiling"
  | `Running -> "   Running"
  | `Creating -> "  Creating"
  | `Removing -> "  Removing"
;;

let verb_message ?(verb_style = default_verb_style) verb object_ =
  [ Pp.text (verb_to_string_padded verb) |> Pp.tag verb_style; Pp.space; Pp.text object_ ]
;;

let default_done_style = Ansi_style.create ~bold:true ~color:`Green ()
let done_message ?(style = default_done_style) () = [ Pp.text "Done!" |> Pp.tag style ]
