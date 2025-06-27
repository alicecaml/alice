open! Alice_stdlib

module Status : sig
  type t =
    | Exited of int
    | Signaled of int
    | Stopped of int

  val to_dyn : t -> Dyn.t
end

module Blocking : sig
  val run
    :  ?stdin:Unix.file_descr
    -> ?stdout:Unix.file_descr
    -> ?stderr:Unix.file_descr
    -> string
    -> args:string list
    -> (Status.t, [ `Prog_not_available ]) result

  val run_command
    :  ?stdin:Unix.file_descr
    -> ?stdout:Unix.file_descr
    -> ?stderr:Unix.file_descr
    -> Command.t
    -> (Status.t, [ `Prog_not_available ]) result
end
