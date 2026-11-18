open! Alice_stdlib
open Alice_engine
open Climate

let build =
  let open Arg_parser in
  let+ () = Common.set_globals_from_flags
  and+ project = Common.parse_project
  and+ build_config = Common.parse_build_config ~default_compiler_backend:Native in
  Project.build project build_config
;;

let subcommand =
  let open Command in
  subcommand "build" ~aliases:[ "b" ] (singleton ~doc:"Build a project." build)
;;
