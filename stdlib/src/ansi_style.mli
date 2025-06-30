module Color : sig
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

val create : ?bold:bool -> ?dim:bool -> ?underline:bool -> ?color:Color.t -> unit -> t
val default : t
val default_with_color : Color.t -> t

(** Call a given function on a formatter with a given style. It is not safe to
    call [pp_with_style] inside [f]. *)
val pp_with_style : t -> Format.formatter -> f:(Format.formatter -> unit) -> unit
