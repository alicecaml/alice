open! Alice_stdlib

module Status : sig
  type t =
    | Exited of int
    | Signaled of int
    | Stopped of int

  val to_dyn : t -> Dyn.t
  val panic_unless_exit_0 : t -> unit
end

module Blocking : sig
  val run
    :  ?stdin:Unix.file_descr
    -> ?stdout:Unix.file_descr
    -> ?stderr:Unix.file_descr
    -> string
    -> args:string list
    -> env:Env.t
    -> (Status.t, [ `Prog_not_available ]) result

  val run_capturing_stdout_lines
    :  ?stdin:Unix.file_descr
    -> ?stderr:Unix.file_descr
    -> string
    -> args:string list
    -> env:Env.t
    -> (Status.t * string list, [ `Prog_not_available ]) result

  val run_command
    :  ?stdin:Unix.file_descr
    -> ?stdout:Unix.file_descr
    -> ?stderr:Unix.file_descr
    -> Command.t
    -> (Status.t, [ `Prog_not_available ]) result

  val run_command_capturing_stdout_lines
    :  ?stdin:Unix.file_descr
    -> ?stderr:Unix.file_descr
    -> Command.t
    -> (Status.t * string list, [ `Prog_not_available ]) result
end
