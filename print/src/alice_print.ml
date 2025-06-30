open! Alice_stdlib

let tag_handler fmt tag pp =
  Ansi_style.pp_with_style tag fmt ~f:(fun fmt -> Pp.to_fmt fmt pp)
;;

let pp_print_gen fmt pp =
  Format.open_box 0;
  Pp.to_fmt_with_tags fmt pp ~tag_handler;
  Format.pp_print_flush fmt ();
  Format.close_box ()
;;

let pps_print_gen fmt pps =
  Format.open_box 0;
  List.iter pps ~f:(fun pp -> Pp.to_fmt_with_tags fmt pp ~tag_handler);
  Format.pp_print_flush fmt ();
  Format.close_box ()
;;

let pp_println_gen fmt pp =
  Format.open_box 0;
  Pp.to_fmt_with_tags fmt pp ~tag_handler;
  Format.pp_print_newline fmt ();
  Format.pp_print_flush fmt ();
  Format.close_box ()
;;

let pps_println_gen fmt pps =
  Format.open_box 0;
  List.iter pps ~f:(fun pp -> Pp.to_fmt_with_tags fmt pp ~tag_handler);
  Format.pp_print_newline fmt ();
  Format.pp_print_flush fmt ();
  Format.close_box ()
;;

let pp_print = pp_print_gen Format.std_formatter
let pp_println = pp_println_gen Format.std_formatter
let pps_print = pps_print_gen Format.std_formatter
let pps_println = pps_println_gen Format.std_formatter
let pp_eprint = pp_print_gen Format.std_formatter
let pp_eprintln = pp_println_gen Format.std_formatter
let pps_eprint = pps_print_gen Format.std_formatter
let pps_eprintln = pps_println_gen Format.std_formatter
