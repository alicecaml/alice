open! Alice_stdlib

type 'a t =
  { os_type : Alice_env.Os_type.t
  ; proc_mgr : 'a Eio.Process.mgr
  ; limit : Concurrency.Limit.t
  }

val create : Alice_env.Os_type.t -> 'a Eio.Process.mgr -> Concurrency.Num_jobs.t -> 'a t
