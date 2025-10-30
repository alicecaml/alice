open! Alice_stdlib
open Alice_engine
open Climate

let run_ =
  let open Arg_parser in
  let+ () = Common.set_globals_from_flags
  and+ project = Common.parse_project
  and+ profile = Common.parse_profile
  and+ args = pos_all string ~doc:"Arguments to pass to the executable." in
  Project.run project profile ~args
;;

let subcommand =
  let open Command in
  subcommand
    "run"
    ~aliases:[ "r" ]
    (singleton ~doc:"Build a project and run its executable." run_)
;;
