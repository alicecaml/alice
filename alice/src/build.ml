open! Alice_stdlib
open Alice_engine
open Climate

let build =
  let open Arg_parser in
  let+ () = Common.set_globals_from_flags
  and+ project = Common.parse_project
  and+ profile = Common.parse_profile
  and+ num_jobs = Common.parse_num_jobs in
  let env = Alice_env.current_env () in
  let os_type = Alice_env.Os_type.current () in
  let ocamlopt = Alice_which.ocamlopt os_type env in
  Eio_main.run
  @@ fun env ->
  let proc_mgr = Eio.Stdenv.process_mgr env in
  let io_ctx = Alice_io.Io_ctx.create os_type proc_mgr num_jobs in
  Project.build project io_ctx profile os_type ocamlopt
;;

let subcommand =
  let open Command in
  subcommand "build" ~aliases:[ "b" ] (singleton ~doc:"Build a project." build)
;;
