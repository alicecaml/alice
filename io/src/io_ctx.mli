open! Alice_stdlib

type 'a t =
  { proc_mgr : 'a Eio.Process.mgr
  ; limit : Concurrency.Limit.t
  }

val create : 'a Eio.Process.mgr -> Concurrency.Num_jobs.t -> 'a t
