open! Alice_stdlib
open Alice_hierarchy
open Alice_engine
open Climate

(** [parse_absolute_path ?dac names] returns a named argument parser of
    absolute path *)
val parse_absolute_path
  :  ?doc:string
  -> string list
  -> Absolute_path.Root_or_non_root.t option Arg_parser.t

val parse_project : Project.t Arg_parser.t
val parse_profile : Profile.t Arg_parser.t

(** Parse the "--verbose" and "--quiet" and have the side effect of setting the
    global log level and print mode. *)
val set_globals_from_flags : unit Arg_parser.t

val parse_num_jobs : Alice_io.Concurrency.Num_jobs.t Arg_parser.t
