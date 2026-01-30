open! Alice_stdlib

type 'a maybe_proc_mgr =
  | Proc_mgr of 'a Eio.Process.mgr
  | Eio_proc_mgr_not_supported_on_platform

val create_maybe_proc_mgr
  :  Alice_env.Os_type.t
  -> (unit -> 'a Eio.Process.mgr)
  -> 'a maybe_proc_mgr

type 'a t =
  { proc_mgr : 'a maybe_proc_mgr
  ; limit : Concurrency.Limit.t
  }

val create : 'a maybe_proc_mgr -> Concurrency.Num_jobs.t -> 'a t
