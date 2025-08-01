open! Alice_stdlib

let panic pps =
  Alice_print.pps_eprint pps;
  exit 1
;;

let user_error pps =
  Alice_print.pps_eprint pps;
  exit 1
;;

