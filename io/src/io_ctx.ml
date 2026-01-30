open! Alice_stdlib

type 'a t =
  { proc_mgr : 'a Eio.Process.mgr
  ; limit : Concurrency.Limit.t
  }

let create proc_mgr num_jobs =
  let limit = Concurrency.Limit.of_num_jobs num_jobs in
  { proc_mgr; limit }
;;
