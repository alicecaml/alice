open! Alice_stdlib
open Alice_engine
open Climate

let build =
  let open Arg_parser in
  let+ () = Common.set_globals_from_flags
  and+ project = Common.parse_project
  and+ profile = Common.parse_profile
  and+ compiler_backend = Common.parse_compiler_backend
  and+ num_jobs = Common.parse_num_jobs
  and+ built_artifacts_from_deps = Common.parse_built_artifacts_from_deps in
  let env = Alice_env.current_env () in
  let os_type = Alice_env.Os_type.current () in
  let ocaml_toolchain = Alice_which.ocaml_toolchain os_type env in
  Project.build
    project
    profile
    os_type
    ocaml_toolchain
    compiler_backend
    num_jobs
    ~built_artifacts_from_deps
;;

let subcommand =
  let open Command in
  subcommand "build" ~aliases:[ "b" ] (singleton ~doc:"Build a project." build)
;;
