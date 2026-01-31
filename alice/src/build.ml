open! Alice_stdlib
open Alice_engine
open Climate

let build =
  let open Arg_parser in
  let+ () = Common.set_globals_from_flags
  and+ project = Common.parse_project
  and+ profile = Common.parse_profile
  and+ num_jobs = Common.parse_num_jobs
  and+ debug_blocking_subprocesses = Common.parse_debug_blocking_subprocesses in
  let env = Alice_env.current_env () in
  let os_type = Alice_env.Os_type.current () in
  let ocamlopt = Alice_which.ocamlopt os_type env in
  Eio_main.run
  @@ fun env ->
  let io_ctx =
    Common.make_io_ctx
      os_type
      num_jobs
      (fun () -> Eio.Stdenv.process_mgr env)
      ~debug_blocking_subprocesses
  in
  Project.build project io_ctx profile os_type ocamlopt
;;

let subcommand =
  let open Command in
  subcommand "build" ~aliases:[ "b" ] (singleton ~doc:"Build a project." build)
;;
