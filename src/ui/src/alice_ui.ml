open! Alice_stdlib
open Alice_hierarchy
open Alice_package_meta
module Raw = Alice_print.Raw

let mode : [ `Standard | `Quiet ] ref = ref `Standard
let set_mode mode' = mode := mode'
let path_style : [ `Native | `Normalized ] ref = ref `Native
let set_normalized_paths () = path_style := `Normalized
let show_time_ref : [ `Show_time | `Hide_time ] ref = ref `Show_time
let set_hide_time () = show_time_ref := `Hide_time
let show_time () = !show_time_ref

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

let absolute_path_to_string : type is_root. is_root Absolute_path.t -> string =
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
       let components =
         match Filename.to_components filename with
         | Absolute { root = _; rest } | Relative rest -> rest
       in
       if List.is_empty components then "." else String.concat ~sep:"/" components)
;;

let basename_to_string basename =
  match !path_style with
  | `Native -> Basename.to_filename basename
  | `Normalized ->
    let basename =
      if Basename.has_extension basename ~ext:".exe"
      then Basename.remove_extension basename
      else basename
    in
    Basename.to_filename basename
;;

let raw_message ?(style = Ansi_style.default) raw = [ Pp.text raw |> Pp.tag style ]
let default_verb_style = Ansi_style.create ~bold:true ~color:`Green ()

type verb =
  [ `Fetching
  | `Unpacking
  | `Building
  | `Running
  | `Creating
  | `Removing
  | `Built
  ]

let verb_to_string_padded = function
  | `Fetching -> " Fetching"
  | `Unpacking -> "Unpacking"
  | `Building -> " Building"
  | `Running -> "  Running"
  | `Creating -> " Creating"
  | `Removing -> " Removing"
  | `Built -> "    Built"
;;

let verb_message ?(verb_style = default_verb_style) verb object_ =
  [ Pp.text (verb_to_string_padded verb) |> Pp.tag verb_style; Pp.space; Pp.text object_ ]
;;

let package_id_style = Ansi_style.create ~bold:true ()

let package_message
      ?(verb_style = default_verb_style)
      ?(pre = [])
      ?(post = [])
      verb
      package_id
  =
  let object_ = Package_id.name_v_version_string package_id in
  List.concat
    [ [ Pp.text (verb_to_string_padded verb) |> Pp.tag verb_style; Pp.space ]
    ; pre
    ; [ Pp.text object_ |> Pp.tag package_id_style ]
    ; post
    ]
;;

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

let config_script_message_begin package_id =
  [ Pp.text "Message from config script of package "
  ; Pp.textf "%s" (Package_id.name_v_version_string package_id) |> Pp.tag package_id_style
  ; Pp.text ":"
  ]
;;

let config_script_message_line text = [ Pp.textf ">  %s" text ]

let config_script_message_end package_id =
  [ Pp.text "End of message ("
  ; Pp.textf "%s" (Package_id.name_v_version_string package_id) |> Pp.tag package_id_style
  ; Pp.text ")."
  ]
;;
