open! Alice_stdlib

module Status : sig
  type t =
    | Exited of int
    | Signaled of int
    | Stopped of int

  val to_dyn : t -> Dyn.t
  val panic_unless_exit_0 : t -> unit
end

module Env_setting : sig
  type t =
    [ `Inherit
    | `Env of Alice_env.Env.t
    ]
end

module Blocking : sig
  val run
    :  ?env:Env_setting.t
    -> ?stdin:Unix.file_descr
    -> ?stdout:Unix.file_descr
    -> ?stderr:Unix.file_descr
    -> string
    -> args:string list
    -> (Status.t, [ `Prog_not_available ]) result

  val run_capturing_stdout_lines
    :  ?env:Env_setting.t
    -> ?stdin:Unix.file_descr
    -> ?stderr:Unix.file_descr
    -> string
    -> args:string list
    -> (Status.t * string list, [ `Prog_not_available ]) result

  val run_command
    :  ?env:Env_setting.t
    -> ?stdin:Unix.file_descr
    -> ?stdout:Unix.file_descr
    -> ?stderr:Unix.file_descr
    -> Command.t
    -> (Status.t, [ `Prog_not_available ]) result

  val run_command_capturing_stdout_lines
    :  ?env:Env_setting.t
    -> ?stdin:Unix.file_descr
    -> ?stderr:Unix.file_descr
    -> Command.t
    -> (Status.t * string list, [ `Prog_not_available ]) result
end
