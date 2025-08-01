open! Alice_stdlib
open Alice_project
open Climate

let build =
  let open Arg_parser in
  let+ project = Common.parse_project in
  Project.clean project
;;

let subcommand =
  let open Command in
  subcommand "clean" (singleton ~doc:"Delete all generated build artifacts." build)
;;
