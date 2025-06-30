open! Alice_stdlib

let panic pps =
  Alice_print.pps_eprintln pps;
  exit 1
;;
