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

  val is_exit_0 : t -> bool
  val error_unless_exit_0 : t -> unit
end

module Running : sig
  type t

  val wait : t -> Report.t
  val poll : t -> Report.t option
  val kill : t -> unit
end

module Running_capturing_stdout : sig
  type t

  val wait_stdout_lines : t -> Report.t * string list
  val poll_stdout_lines : t -> (Report.t * string list) option
end

module Error : sig
  type t = [ `Prog_not_available of string ]
end

val run
  :  ?stdin:Unix.file_descr
  -> ?stdout:Unix.file_descr
  -> ?stderr:Unix.file_descr
  -> string
  -> args:string list
  -> env:Env.t
  -> (Running.t, Error.t) result

val run_capturing_stdout
  :  ?stdin:Unix.file_descr
  -> ?stderr:Unix.file_descr
  -> string
  -> args:string list
  -> env:Env.t
  -> (Running_capturing_stdout.t, Error.t) result

val run_command
  :  ?stdin:Unix.file_descr
  -> ?stdout:Unix.file_descr
  -> ?stderr:Unix.file_descr
  -> Command.t
  -> (Running.t, Error.t) result

val run_command_capturing_stdout
  :  ?stdin:Unix.file_descr
  -> ?stderr:Unix.file_descr
  -> Command.t
  -> (Running_capturing_stdout.t, Error.t) result

module Blocking : sig
  val run
    :  ?stdin:Unix.file_descr
    -> ?stdout:Unix.file_descr
    -> ?stderr:Unix.file_descr
    -> string
    -> args:string list
    -> env:Env.t
    -> (Report.t, Error.t) result

  val run_capturing_stdout_lines
    :  ?stdin:Unix.file_descr
    -> ?stderr:Unix.file_descr
    -> string
    -> args:string list
    -> env:Env.t
    -> (Report.t * string list, Error.t) result

  val run_command
    :  ?stdin:Unix.file_descr
    -> ?stdout:Unix.file_descr
    -> ?stderr:Unix.file_descr
    -> Command.t
    -> (Report.t, Error.t) result

  val run_command_capturing_stdout_lines
    :  ?stdin:Unix.file_descr
    -> ?stderr:Unix.file_descr
    -> Command.t
    -> (Report.t * string list, Error.t) result
end

val run_batch_map_stdout_lines
  :  Command.t list
  -> Num_jobs.t
  -> f:(string list -> 'a)
  -> 'a list
