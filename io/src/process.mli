open! Alice_stdlib

module Status : sig
  type t =
    | Exited of int
    | Signaled of int
    | Stopped of int

  val to_dyn : t -> Dyn.t
end

module Report : sig
  type t =
    { status : Status.t
    ; command : Command.t
    }

  val error_unless_exit_0 : t -> unit
end

module Blocking : sig
  val run
    :  ?stdin:Unix.file_descr
    -> ?stdout:Unix.file_descr
    -> ?stderr:Unix.file_descr
    -> string
    -> args:string list
    -> env:Env.t
    -> (Report.t, [ `Prog_not_available ]) result

  val run_capturing_stdout_lines
    :  ?stdin:Unix.file_descr
    -> ?stderr:Unix.file_descr
    -> string
    -> args:string list
    -> env:Env.t
    -> (Report.t * string list, [ `Prog_not_available ]) result

  val run_command
    :  ?stdin:Unix.file_descr
    -> ?stdout:Unix.file_descr
    -> ?stderr:Unix.file_descr
    -> Command.t
    -> (Report.t, [ `Prog_not_available ]) result

  val run_command_capturing_stdout_lines
    :  ?stdin:Unix.file_descr
    -> ?stderr:Unix.file_descr
    -> Command.t
    -> (Report.t * string list, [ `Prog_not_available ]) result
end
