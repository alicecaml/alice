open! Alice_stdlib
open Alice_engine
open Climate

let build =
  let open Arg_parser in
  let+ () = Common.set_globals_from_flags
  and+ project = Common.parse_project
  and+ build_config = Common.parse_build_config ~default_compiler_backend:Native
  and+ built_artifacts_from_deps = Common.parse_built_artifacts_from_deps in
  Project.build project build_config ~built_artifacts_from_deps
;;

let subcommand =
  let open Command in
  subcommand "build" ~aliases:[ "b" ] (singleton ~doc:"Build a project." build)
;;
