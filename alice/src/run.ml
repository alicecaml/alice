open! Alice_stdlib
open Alice_project
open Climate

let build =
  let open Arg_parser in
  let+ () = Common.set_log_level_from_verbose_flag
  and+ project = Common.parse_project
  and+ ctx = Common.parse_ctx
  and+ args = pos_all string ~doc:"Arguments to pass to the executable." in
  Project.run_ocaml_exe ~ctx project ~args
;;

let subcommand =
  let open Command in
  subcommand "run" (singleton ~doc:"Build a project and run its executable." build)
;;
