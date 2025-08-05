open! Alice_stdlib
open Alice_project
open Climate

let dot =
  let open Arg_parser in
  let+ () = Common.set_log_level_from_verbose_flag
  and+ project = Common.parse_project
  and+ ctx = Common.parse_ctx in
  print_endline (Project.dot_ocaml_exe ~ctx project)
;;

let subcommand =
  let open Command in
  subcommand
    "dot"
    (singleton ~doc:"Print graphviz source describing build artifact dependencies." dot)
;;
