open! Alice_stdlib
open Alice_hierarchy
open Alice_engine
open Alice_ocaml_toolchain
open Climate

(** [parse_absolute_path ?dac names] returns a named argument parser of
    absolute path *)
val parse_absolute_path
  :  ?doc:string
  -> string list
  -> Absolute_path.Root_or_non_root.t option Arg_parser.t

val parse_project : Project.t Arg_parser.t
val parse_profile : Profile.t Arg_parser.t
val parse_compiler_backend : Compiler_backend.t Arg_parser.t

(** Parse the "--verbose" and "--quiet" and have the side effect of setting the
    global log level and print mode. *)
val set_globals_from_flags : unit Arg_parser.t

val parse_num_jobs : Alice_io.Num_jobs.t Arg_parser.t
val parse_debug_blocking_subprocesses : bool Arg_parser.t
val parse_built_artifacts_from_deps : bool Arg_parser.t
val parse_build_config : Build_config.t Arg_parser.t
