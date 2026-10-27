open! Alice_stdlib
open Alice_engine
open Climate

let run_ =
  let open Arg_parser in
  let+ () = Common.set_globals_from_flags
  and+ project = Common.parse_project
  and+ build_config = Common.parse_build_config
  and+ built_artifacts_from_deps = Common.parse_built_artifacts_from_deps
  and+ args =
    pos_all string ~doc:"Arguments to pass to the executable." ~value_name:"ARGS"
  in
  Project.run project build_config ~args ~built_artifacts_from_deps
;;

let subcommand =
  let open Command in
  subcommand
    "run"
    ~aliases:[ "r" ]
    (singleton ~doc:"Build a project and run its executable." run_)
;;
