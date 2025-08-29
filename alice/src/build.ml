open! Alice_stdlib
open Alice_project
open Climate

let build =
  let open Arg_parser in
  let+ () = Common.set_globals_from_flags
  and+ project = Common.parse_project
  and+ ctx = Common.parse_ctx in
  Project.build_ocaml ~ctx project
;;

let subcommand =
  let open Command in
  subcommand "build" ~aliases:[ "b" ] (singleton ~doc:"Build a project." build)
;;
