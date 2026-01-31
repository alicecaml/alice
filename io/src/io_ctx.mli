open! Alice_stdlib

type 'a t =
  { proc_mgr : 'a Eio.Process.mgr option
  ; limit : Concurrency.Limit.t
  }

val create : 'a Eio.Process.mgr option -> Concurrency.Num_jobs.t -> 'a t
