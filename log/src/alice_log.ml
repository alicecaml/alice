open! Alice_stdlib

type level =
  [ `Debug
  | `Info
  | `Warn
  | `Error
  ]

let current_level : level ref = ref `Error
let set_level level = current_level := level

let to_int = function
  | `Debug -> 0
  | `Info -> 1
  | `Warn -> 2
  | `Error -> 3
;;

let tag_debug = Ansi_style.create ~color:`Magenta ()
let tag_info = Ansi_style.create ~color:`Blue ()
let tag_warn = Ansi_style.create ~color:`Yellow ()
let tag_error = Ansi_style.create ~color:`Red ()
let tag_package = Ansi_style.create ~color:`Cyan ()

type pos = string * int * int * int

let pp_pos (file, lnum, _cnum, _enum) = Pp.textf "%s:%d" file lnum

let log ?pos ?package ~level message =
  if to_int level >= to_int !current_level
  then (
    let prefix =
      match level with
      | `Debug -> Pp.tag tag_debug (Pp.text "[DEBUG] ")
      | `Info -> Pp.tag tag_info (Pp.text " [INFO] ")
      | `Warn -> Pp.tag tag_warn (Pp.text " [WARN] ")
      | `Error -> Pp.tag tag_error (Pp.text "[ERROR] ")
    in
    let message =
      match package with
      | None -> message
      | Some package ->
        Pp.tag
          tag_package
          (Pp.textf "[%s] " (Alice_package.Package_id.name_v_version_string package))
        :: message
    in
    let message =
      match pos with
      | None -> message
      | Some pos -> pp_pos pos :: message
    in
    Alice_print.Raw.pps_eprintln (prefix :: message))
;;

let debug ?pos ?package message = log ?pos ?package ~level:`Debug message
let info ?pos ?package message = log ?pos ?package ~level:`Info message
let warn ?pos ?package message = log ?pos ?package ~level:`Warn message
let error ?pos ?package message = log ?pos ?package ~level:`Error message
