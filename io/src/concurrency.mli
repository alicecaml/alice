open! Alice_stdlib

module Num_jobs : sig
  type t

  val limited : int -> t
  val unlimited : t
end

module Limit : sig
  type t

  val of_num_jobs : Num_jobs.t -> t

  (** Call [f], running no more than the limit of concurrent fibers. *)
  val run : t -> f:(unit -> 'a) -> 'a
end
