open! Alice_stdlib
open Alice_project
open Alice_hierarchy
open Climate

val parse_absolute_path
  :  ?doc:string
  -> string list
  -> Path.Absolute.t option Arg_parser.t

val parse_project : Project.t Arg_parser.t
val parse_ctx : Alice_policy.Ocaml.Ctx.t Arg_parser.t
