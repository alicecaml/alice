open! Alice_stdlib
open Alice_project
open Climate

let dot =
  let open Arg_parser in
  let+ () = Common.set_globals_from_flags
  and+ project = Common.parse_project
  and+ packages = flag [ "packages" ] ~doc:"Print package dependency graph."
  and+ artifacts =
    flag [ "artifacts" ] ~doc:"Print build artifact dependency graph (default)."
  in
  if packages && artifacts
  then
    Alice_error.user_exn [ Pp.text "--packages and --artifacts are mutually exclusive" ];
  let dot_source =
    if packages
    then Project.dot_package_dependencies project
    else Project.dot_build_artifacts project
  in
  print_endline dot_source
;;

let subcommand =
  let open Command in
  subcommand
    "dot"
    (singleton ~doc:"Print graphviz source describing build artifact dependencies." dot)
;;
