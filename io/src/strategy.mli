open! Alice_stdlib

module Parallel_with_eio : sig
  module Num_jobs : sig
    type t

    val limited : int -> t
    val unlimited : t
  end

  module Limit : sig
    type t

    (** Call [f], running no more than the limit of concurrent fibers. *)
    val run : t -> f:(unit -> 'a) -> 'a
  end

  type 'a t =
    { proc_mgr : 'a Eio.Process.mgr
    ; limit : Limit.t
    }
end

type 'a t =
  | Sequential
  | Parallel_with_eio of 'a Parallel_with_eio.t

val sequential : _ t
val parallel_with_eio : 'a Eio.Process.mgr -> Parallel_with_eio.Num_jobs.t -> 'a t
