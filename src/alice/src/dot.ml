open! Alice_stdlib
open Alice_engine
open Climate

let dot_artifacts =
  let open Arg_parser in
  let+ () = Common.set_globals_from_flags
  and+ project = Common.parse_project
  and+ build_config = Common.parse_build_config ~default_compiler_backend:Native in
  print_endline @@ Project.dot_build_artifacts project build_config
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
