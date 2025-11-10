open! Alice_stdlib
open Alice_engine
open Climate

let build =
  let open Arg_parser in
  let+ () = Common.set_globals_from_flags
  and+ project = Common.parse_project
  and+ profile = Common.parse_profile in
  let env = Alice_env.current_env () in
  let os_type = Alice_env.Os_type.current () in
  let ocamlopt = Alice_which.ocamlopt os_type env in
  Project.build project profile os_type ocamlopt
;;

let subcommand =
  let open Command in
  subcommand "build" ~aliases:[ "b" ] (singleton ~doc:"Build a project." build)
;;
