open! Alice_stdlib
open Alice_engine
open Climate

let dot_artifacts =
  let open Arg_parser in
  let+ () = Common.set_globals_from_flags
  and+ project = Common.parse_project in
  let env = Alice_env.Env.current () in
  let ocamlopt = Alice_which.ocamlopt env in
  print_endline @@ Project.dot_build_artifacts project ocamlopt
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
       [ subcommand "artifacts" (singleton ~doc:"Vizualize the build plan." dot_artifacts)
       ; subcommand
           "packages"
           (singleton ~doc:"Vizualize the package dependency graph." dot_packages)
       ])
;;
