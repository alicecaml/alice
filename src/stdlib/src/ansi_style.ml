module Color = struct
  type t =
    [ `Black
    | `Red
    | `Green
    | `Yellow
    | `Blue
    | `Magenta
    | `Cyan
    | `White
    | `Bright_black
    | `Bright_red
    | `Bright_green
    | `Bright_yellow
    | `Bright_blue
    | `Bright_magenta
    | `Bright_cyan
    | `Bright_white
    ]
end

type t =
  { bold : bool
  ; dim : bool
  ; underline : bool
  ; color : Color.t option
  }

let create ?(bold = false) ?(dim = false) ?(underline = false) ?color () =
  { bold; dim; underline; color }
;;

(* This is what the style will be after the terminal is reset. *)
let default = { bold = false; dim = false; underline = false; color = None }
let default_with_color color = { default with color = Some color }
let reset = "\x1b[0m"

let is_default { bold; dim; underline; color } =
  (not bold) && (not dim) && (not underline) && Option.is_none color
;;

let escape { bold; dim; underline; color } =
  let effects =
    List.concat
      [ (if bold then [ ";1" ] else [])
      ; (if dim then [ ";2" ] else [])
      ; (if underline then [ ";4" ] else [])
      ]
  in
  let color_code =
    match (color : Color.t option) with
    | None -> 0
    | Some `Black -> 30
    | Some `Red -> 31
    | Some `Green -> 32
    | Some `Yellow -> 33
    | Some `Blue -> 34
    | Some `Magenta -> 35
    | Some `Cyan -> 36
    | Some `White -> 37
    | Some `Bright_black -> 90
    | Some `Bright_red -> 91
    | Some `Bright_green -> 92
    | Some `Bright_yellow -> 93
    | Some `Bright_blue -> 94
    | Some `Bright_magenta -> 95
    | Some `Bright_cyan -> 96
    | Some `Bright_white -> 97
  in
  Printf.sprintf "\x1b[%d%sm" color_code (String.concat ~sep:"" effects)
;;

let pp_with_style t ppf ~f =
  if not (is_default t) then Format.pp_print_string ppf (escape t);
  f ppf;
  if not (is_default t) then Format.pp_print_string ppf reset
;;
