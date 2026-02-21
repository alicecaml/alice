open! Alice_stdlib

type 'a t =
  { proc_mgr : 'a Eio.Process.mgr option
  ; limit : Concurrency.Limit.t
  ; num_jobs : Concurrency.Num_jobs.t
  }

let create proc_mgr num_jobs =
  let limit = Concurrency.Limit.of_num_jobs num_jobs in
  { proc_mgr; limit; num_jobs }
;;
