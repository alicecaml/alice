open! Alice_stdlib

let tag_handler fmt tag pp =
  Ansi_style.pp_with_style tag fmt ~f:(fun fmt -> Pp.to_fmt fmt pp)
;;

let pp_print_stderr pp =
  let fmt = Format.err_formatter in
  Pp.to_fmt_with_tags fmt pp ~tag_handler;
  Format.pp_print_flush fmt ()
;;

let panic pps =
  List.iter pps ~f:pp_print_stderr;
  Format.pp_print_newline Format.err_formatter ();
  exit 1
;;
