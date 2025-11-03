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

let path_to_string : type is_root. is_root Absolute_path.t -> string =
  fun path ->
  match !path_style with
  | `Native -> Absolute_path.to_filename path
  | `Normalized ->
    (match Absolute_path.is_root path with
     | True -> "/"
     | False ->
       let path =
         if Absolute_path.has_extension path ~ext:".exe"
         then Absolute_path.remove_extension path
         else path
       in
       let filename =
         Absolute_path.to_filename path
         |> Filename.chop_prefix
              ~prefix:(Absolute_path.Root_or_non_root.to_filename Alice_env.initial_cwd)
       in
       (* The start of the path will always be a period. Skip it. *)
       let (_current_dir :: components) = Filename.to_components filename in
       if List.is_empty components then "." else String.concat ~sep:"/" components)
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
  | `Finished
  ]

let verb_to_string_padded = function
  | `Fetching -> "  Fetching"
  | `Unpacking -> " Unpacking"
  | `Compiling -> " Compiling"
  | `Running -> "   Running"
  | `Creating -> "  Creating"
  | `Removing -> "  Removing"
  | `Finished -> "  Finished"
;;

let verb_message ?(verb_style = default_verb_style) verb object_ =
  [ Pp.text (verb_to_string_padded verb) |> Pp.tag verb_style; Pp.space; Pp.text object_ ]
;;

let default_done_style = Ansi_style.create ~bold:true ~color:`Green ()
let done_message ?(style = default_done_style) () = [ Pp.text "Done!" |> Pp.tag style ]

(* Returns a thunk than invokes a given think the first time it's called. *)
let once f =
  let called = ref false in
  fun () ->
    if not !called
    then (
      called := true;
      f ())
;;

let println_once pps = once (fun () -> println pps)
