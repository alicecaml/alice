open! Alice_stdlib
open Alice_project
open Alice_hierarchy
open Climate

(** [parse_absolute_path ?dac names] returns a named argument parser of
    absolute path *)
val parse_absolute_path
  :  ?doc:string
  -> string list
  -> Path.Absolute.t option Arg_parser.t

val parse_project : Project.t Arg_parser.t
val parse_ctx : Alice_policy.Ocaml.Ctx.t Arg_parser.t

(** Parse the "--verbose" and "--quiet" and have the side effect of setting the
    global log level and print mode. *)
val set_globals_from_flags : unit Arg_parser.t
