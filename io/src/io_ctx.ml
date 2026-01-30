open! Alice_stdlib

type 'a maybe_proc_mgr =
  | Proc_mgr of 'a Eio.Process.mgr
  | Eio_proc_mgr_not_supported_on_platform

let create_maybe_proc_mgr os_type proc_mgr_thunk =
  if Alice_env.Os_type.is_windows os_type
  then Eio_proc_mgr_not_supported_on_platform
  else Proc_mgr (proc_mgr_thunk ())
;;

type 'a t =
  { proc_mgr : 'a maybe_proc_mgr
  ; limit : Concurrency.Limit.t
  }

let create proc_mgr num_jobs =
  let limit = Concurrency.Limit.of_num_jobs num_jobs in
  { proc_mgr; limit }
;;
