open! Alice_stdlib
open Alice_engine
open Climate

let run_ =
  let open Arg_parser in
  let+ () = Common.set_globals_from_flags
  and+ project = Common.parse_project
  and+ profile = Common.parse_profile
  and+ num_jobs = Common.parse_num_jobs
  and+ args =
    pos_all string ~doc:"Arguments to pass to the executable." ~value_name:"ARGS"
  in
  let env = Alice_env.current_env () in
  let os_type = Alice_env.Os_type.current () in
  let ocamlopt = Alice_which.ocamlopt os_type env in
  Eio_main.run
  @@ fun env ->
  let proc_mgr = Eio.Stdenv.process_mgr env in
  let io_ctx = Alice_io.Io_ctx.create proc_mgr num_jobs in
  Project.run project io_ctx profile os_type ocamlopt ~args
;;

let subcommand =
  let open Command in
  subcommand
    "run"
    ~aliases:[ "r" ]
    (singleton ~doc:"Build a project and run its executable." run_)
;;
