open! Alice_stdlib
open Alice_project
open Climate

let build =
  let open Arg_parser in
  let+ project = Common.parse_project
  and+ ctx = Common.parse_ctx in
  Project.build_ocaml_exe ~ctx project
;;

let subcommand =
  let open Command in
  subcommand "build" (singleton ~doc:"Build a project." build)
;;
