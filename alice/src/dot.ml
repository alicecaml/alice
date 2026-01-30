open! Alice_stdlib
open Alice_engine
open Climate

let dot_artifacts =
  let open Arg_parser in
  let+ () = Common.set_globals_from_flags
  and+ project = Common.parse_project
  and+ num_jobs = Common.parse_num_jobs in
  let env = Alice_env.current_env () in
  let os_type = Alice_env.Os_type.current () in
  let ocamlopt = Alice_which.ocamlopt os_type env in
  Eio_main.run
  @@ fun env ->
  let proc_mgr = Eio.Stdenv.process_mgr env in
  let io_ctx = Alice_io.Io_ctx.create proc_mgr num_jobs in
  print_endline @@ Project.dot_build_artifacts project io_ctx os_type ocamlopt
;;

let dot_packages =
  let open Arg_parser in
  let+ () = Common.set_globals_from_flags
  and+ project = Common.parse_project in
  print_endline @@ Project.dot_dependencies project
;;

let subcommand =
  let open Command in
  subcommand
    "dot"
    (group
       ~doc:"Print graphviz source files."
       [ subcommand "artifacts" (singleton ~doc:"Visualize the build plan." dot_artifacts)
       ; subcommand
           "packages"
           (singleton ~doc:"Visualize the package dependency graph." dot_packages)
       ])
;;
