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

module Eio : sig
  type error =
    [ `Program_not_available of string
    | `Generic_error of string
    ]

  val result_ok_or_exn : ('a, error) result -> 'a

  val run
    :  _ Eio.Process.mgr
    -> string
    -> args:string list
    -> env:Env.t
    -> (unit, error) result

  val run_command : _ Eio.Process.mgr -> Command.t -> (unit, error) result

  val run_capturing_stdout_lines
    :  _ Eio.Process.mgr
    -> string
    -> args:string list
    -> env:Env.t
    -> (string list, error) result

  val run_command_capturing_stdout_lines
    :  _ Eio.Process.mgr
    -> Command.t
    -> (string list, error) result
end
