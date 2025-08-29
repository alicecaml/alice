open! Alice_stdlib
open Alice_project
open Climate

let clean =
  let open Arg_parser in
  let+ () = Common.set_globals_from_flags
  and+ project = Common.parse_project in
  Project.clean project
;;

let subcommand =
  let open Command in
  subcommand
    "clean"
    ~aliases:[ "c" ]
    (singleton ~doc:"Delete all generated build artifacts." clean)
;;
