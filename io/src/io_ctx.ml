open! Alice_stdlib

type 'a t =
  { os_type : Alice_env.Os_type.t
  ; proc_mgr : 'a Eio.Process.mgr
  ; limit : Concurrency.Limit.t
  }

let create os_type proc_mgr num_jobs =
  let limit = Concurrency.Limit.of_num_jobs num_jobs in
  { os_type; proc_mgr; limit }
;;
