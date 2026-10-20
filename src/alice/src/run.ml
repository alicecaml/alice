open! Alice_stdlib
open Alice_engine
open Climate

let run_ =
  let open Arg_parser in
  let+ () = Common.set_globals_from_flags
  and+ project = Common.parse_project
  and+ profile = Common.parse_profile
  and+ num_jobs = Common.parse_num_jobs
  and+ built_artifacts_from_deps = Common.parse_built_artifacts_from_deps
  and+ args =
    pos_all string ~doc:"Arguments to pass to the executable." ~value_name:"ARGS"
  in
  let env = Alice_env.current_env () in
  let os_type = Alice_env.Os_type.current () in
  let ocaml_toolchain = Alice_which.ocaml_toolchain os_type env in
  Project.run
    project
    profile
    os_type
    ocaml_toolchain
    ~args
    num_jobs
    ~built_artifacts_from_deps
;;

let subcommand =
  let open Command in
  subcommand
    "run"
    ~aliases:[ "r" ]
    (singleton ~doc:"Build a project and run its executable." run_)
;;
